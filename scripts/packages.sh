#!/usr/bin/env bash
set -e

# -----------------------------
# CONFIG
# -----------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------
# XDG environment (defensive)
# -----------------------------
# Normally already exported by install.sh/bootstrap.sh before this script
# runs, but set it up here too in case packages.sh is ever run on its own.
# Idempotent — see scripts/lib-xdg.sh.
. "$REPO_ROOT/scripts/lib-xdg.sh"
zexos_setup_xdg_env

LOGFILE="$REPO_ROOT/packages.log"
mkdir -p "$REPO_ROOT"
exec > >(tee -a "$LOGFILE") 2>&1

# -----------------------------
# COLORS
# -----------------------------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# -----------------------------
# SPINNER
# -----------------------------
spinner() {
    local pid=$1
    local msg=$2
    local spin='|/-\'

    echo -ne "${CYAN}${msg}${RESET} "

    while kill -0 "$pid" 2>/dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\b${spin:$i:1}"
            sleep 0.1
        done
    done

    echo -e "\b✔"
}

# -----------------------------
# ASCII HEADER
# -----------------------------
clear
cat << "EOF"

███████╗███████╗██╗  ██╗ ██████╗ ███████╗
╚══███╔╝██╔════╝╚██╗██╔╝██╔═══██╗██╔════╝
  ███╔╝ █████╗   ╚███╔╝ ██║   ██║███████╗
 ███╔╝  ██╔══╝   ██╔██╗ ██║   ██║╚════██║
███████╗███████╗██╗  ██╗╚██████╔╝███████║
╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

        ZeXOS PACKAGE INSTALLER
EOF

echo -e "${BLUE}GitHub: https://github.com/zefuros1991/ZeXOS${RESET}"
echo -e "${BLUE}Log: $LOGFILE${RESET}"
echo "--------------------------------------------------"

# -----------------------------
# SUDO KEEPALIVE (standalone safety)
# -----------------------------
# This script needs sudo for every pacman call plus the SDDM setup below.
# Normally install.sh already keeps sudo warm for the whole run, so this
# `sudo -v` is a harmless no-op refresh in that case. When packages.sh is
# run standalone with a cold sudo cache, this prompts once up front instead
# of leaving that to whichever backgrounded pacman call happens to need it
# first.
echo -e "\n${YELLOW}==> AUTHENTICATION${RESET}"
sudo -v

(
    while true; do
        sudo -n true
        sleep 50
    done
) &

SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

# makepkg normally calls "sudo -k", which forgets the password on purpose
# and asks for it again each time it installs something. This wrapper runs
# makepkg with a copy of your normal settings plus PACMAN_AUTH=(sudo), so it
# uses the password you already typed at the start.
MAKEPKG_CONF_ZEXOS="$(mktemp)"
{
    cat /etc/makepkg.conf
    cat /etc/makepkg.conf.d/*.conf 2>/dev/null || true
    # Your own makepkg.conf, if you have one (most people don't).
    cat "${XDG_CONFIG_HOME:-$HOME/.config}/pacman/makepkg.conf" 2>/dev/null \
        || cat "$HOME/.makepkg.conf" 2>/dev/null || true
    echo 'PACMAN_AUTH=(sudo)'
} > "$MAKEPKG_CONF_ZEXOS"
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true; rm -f "$MAKEPKG_CONF_ZEXOS"' EXIT

zexos_makepkg() {
    makepkg --config "$MAKEPKG_CONF_ZEXOS" "$@"
}

# -----------------------------
# 0.5 SYSTEM UPGRADE
# -----------------------------
echo -e "\n${YELLOW}[SYSTEM] Full System Upgrade${RESET}"

sudo pacman -Syu --noconfirm &
sysupgrade_pid=$!
spinner "$sysupgrade_pid" "Updating system"

if wait "$sysupgrade_pid"; then
    echo -e "${GREEN}✔ System upgrade completed${RESET}"
else
    echo -e "${RED}✖ System upgrade failed — continuing anyway, but package installs below may also fail${RESET}"
fi

# =========================================================
# 1. PACMAN PACKAGES
# =========================================================

install_pacman() {
    local label=$1
    shift
    local pkgs=("$@")

    echo -e "\n${YELLOW}[PACMAN] ${label}${RESET}"

    for pkg in "${pkgs[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            echo -e "${GREEN}✔ $pkg already installed${RESET}"
        else
            echo -e "${CYAN}Installing $pkg${RESET}"

            sudo pacman -S --needed --noconfirm "$pkg" &
            spinner $! "Installing $pkg"

            if pacman -Qi "$pkg" &>/dev/null; then
                echo -e "${GREEN}✔ $pkg installed successfully${RESET}"
            else
                echo -e "${RED}✖ Failed to install $pkg${RESET}"
            fi
        fi
    done
}

# -----------------------------
# DESKTOP CORE
# -----------------------------
# The compositor, launcher and terminal ZeXOS is built around. CachyOS's
# niri profile already ships most of these; --needed makes this a no-op
# there and fills the gaps on plain Arch.
CORE_PACMAN=(
    niri
    xwayland-satellite
    fuzzel
    kitty
    zsh
    neovim
    adw-gtk-theme
    fastfetch
    imagemagick
    ttf-jetbrains-mono-nerd
)

install_pacman "Desktop Core" "${CORE_PACMAN[@]}"

# The zsh config builds on CachyOS's own zsh setup (prompt, plugins). That
# package only exists in the CachyOS repos; on plain Arch the zsh config
# still loads, just without it.
if pacman -Si cachyos-zsh-config &>/dev/null; then
    install_pacman "CachyOS zsh config" cachyos-zsh-config
fi

# -----------------------------
# MEDIA BASICS
# -----------------------------
MEDIA_PACMAN=(
    vlc
    ffmpeg
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
)

install_pacman "Media Basics" "${MEDIA_PACMAN[@]}"

# -----------------------------
# SYSTEM
# -----------------------------
# xorg-xhost and polkit-kde-agent make privileged GUI apps (gparted and
# friends) actually work out of the box under niri + Xwayland:
#   - polkit-kde-agent is the auth agent niri's autostart.kdl spawns
#     (`/usr/lib/polkit-kde-authentication-agent-1`) -- without it pkexec
#     fails immediately with "No authentication agent found".
#   - xorg-xhost is a soft dependency of gparted's own launcher script,
#     which grants the pkexec'd root process X access via `xhost` before
#     handing off. Without it, auth succeeds but the root GUI process can't
#     open the display ("cannot open display" Gtk-WARNING).
SYSTEM_PACMAN=(
    btop
    gparted
    xorg-xhost
    polkit-kde-agent
)

install_pacman "System Tools" "${SYSTEM_PACMAN[@]}"

# -----------------------------
# FILE MANAGER (DOLPHIN)
# -----------------------------
# Nautilus was the niri default but couldn't do pinned/mounted-partition
# sidebar entries or a working "set as default app" flow. Switched to
# Dolphin (2026-09-03) -- kio-extras adds network/archive/etc backends to
# its sidebar, kde-cli-tools brings kioclient/kwrite helpers it shells out
# to. Confirmed working under niri.
FILE_MANAGER_PACMAN=(
    dolphin
    kio-extras
    kde-cli-tools
    gwenview
)

install_pacman "File Manager (Dolphin)" "${FILE_MANAGER_PACMAN[@]}"

# -----------------------------
# PACKAGE MANAGER APP (SHELLY)
# -----------------------------
# Shelly is a point-and-click app for installing and updating software
# (Mod+M opens it). It is only in the CachyOS repos, so skip it elsewhere.
if pacman -Si shelly &>/dev/null; then
    install_pacman "Package manager app (Shelly)" shelly
fi

# -----------------------------
# NOCTALIA EXTRAS
# -----------------------------
# udiskie/udisks2/xdg-utils: the aristides/udiskie plugin (USB widget in the
# bar) shells out to all three. layer-shell-qt + build tools: roller, below.
NOCTALIA_PACMAN=(
    udiskie
    udisks2
    xdg-utils
    layer-shell-qt
    cmake
)

install_pacman "Noctalia Extras" "${NOCTALIA_PACMAN[@]}"

# -----------------------------
# ROLLER (wallpaper picker, Mod+W)
# -----------------------------
# Not in the repos -- built from packaging/roller (upstream pinned to a known
# commit + our wheel/size patch). Config and the waypaper->noctalia shim live
# in stow/roller. Rebuilt only when the installed pkgrel differs from ours.
echo -e "\n${YELLOW}[CUSTOM] Roller${RESET}"

ROLLER_WANT="$(. "$REPO_ROOT/packaging/roller/PKGBUILD"; echo "$pkgver-$pkgrel")"
if [ "$(pacman -Q roller 2>/dev/null | awk '{print $2}')" = "$ROLLER_WANT" ]; then
    echo -e "${GREEN}✔ roller $ROLLER_WANT already installed${RESET}"
else
    roller_build="$(mktemp -d)"
    cp "$REPO_ROOT"/packaging/roller/* "$roller_build/"
    if (cd "$roller_build" && zexos_makepkg -si --noconfirm --needed); then
        echo -e "${GREEN}✔ roller $ROLLER_WANT installed${RESET}"
    else
        echo -e "${RED}✖ roller build failed -- Mod+W won't open a picker${RESET}"
    fi
    rm -rf "$roller_build"
fi

# -----------------------------
# NOCTALIA (patched: bar islands attached to the top edge, bigger launcher)
# -----------------------------
# The stock package comes with CachyOS's niri profile. We swap it for
# packaging/noctalia-zexos: the official Arch PKGBUILD plus a small patch
# that adds `attached = true` to bar capsule groups (square top corners,
# round bottom ones) and `[accessibility] launcher_scale` (launcher-only size). Separate package name, so repo updates can't undo it.
echo -e "\n${YELLOW}[CUSTOM] Noctalia (ZeXOS patch)${RESET}"

NOCTALIA_WANT="$(. "$REPO_ROOT/packaging/noctalia-zexos/PKGBUILD"; echo "$pkgver-$pkgrel")"
if [ "$(pacman -Q noctalia-zexos 2>/dev/null | awk '{print $2}')" = "$NOCTALIA_WANT" ]; then
    echo -e "${GREEN}✔ noctalia-zexos $NOCTALIA_WANT already installed${RESET}"
else
    noctalia_build="$(mktemp -d)"
    cp "$REPO_ROOT"/packaging/noctalia-zexos/* "$noctalia_build/"
    if (cd "$noctalia_build" && zexos_makepkg -s --noconfirm --needed); then
        # --noconfirm answers "no" to the conflict prompt, so drop stock first
        pacman -Q noctalia >/dev/null 2>&1 && sudo pacman -Rdd --noconfirm noctalia
        sudo pacman -U --noconfirm "$noctalia_build"/noctalia-zexos-*.pkg.tar.zst
        echo -e "${GREEN}✔ noctalia-zexos $NOCTALIA_WANT installed${RESET}"
    else
        echo -e "${RED}✖ noctalia-zexos build failed -- stock noctalia kept, bar islands will float${RESET}"
    fi
    rm -rf "$noctalia_build"
fi

# -----------------------------
# ZEN BROWSER INSTALL
# -----------------------------
echo -e "\n${YELLOW}[CUSTOM] Zen Browser${RESET}"

# The installer this script calls actually names its binary "zen" (found at
# /opt/zen/zen, symlinked to /usr/local/bin/zen), never "zen-browser" — the
# old check here never matched, so this curl-pipe-to-bash installer used to
# re-run on every single invocation of this script even when Zen was
# already installed.
if command -v zen >/dev/null 2>&1 || [ -x /opt/zen/zen ]; then
    echo -e "${GREEN}✔ Zen Browser already installed${RESET}"
else
    bash <(curl -fsSL https://raw.githubusercontent.com/MalikHw/zb-installer-script/main/install-zen.sh)
fi

# =========================================================
# 2. PACKAGES BUILT HERE (no AUR)
# =========================================================
# A few things aren't in the CachyOS/Arch repos. Instead of using the AUR,
# each has a small recipe in packaging/ that downloads it straight from its
# author and checks it against a fixed checksum. makepkg turns it into a
# normal package, so pacman can update or remove it like any other.

install_local() {
    local label=$1 dir=$2
    local pkg want
    pkg="$(. "$REPO_ROOT/packaging/$dir/PKGBUILD"; echo "$pkgname")"
    want="$(. "$REPO_ROOT/packaging/$dir/PKGBUILD"; echo "$pkgver-$pkgrel")"

    echo -e "\n${YELLOW}[LOCAL] ${label}${RESET}"

    if [ "$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')" = "$want" ]; then
        echo -e "${GREEN}✔ $pkg $want already installed${RESET}"
        return 0
    fi

    local build
    build="$(mktemp -d)"
    cp "$REPO_ROOT/packaging/$dir"/* "$build/"
    if (cd "$build" && zexos_makepkg -si --noconfirm --needed); then
        echo -e "${GREEN}✔ $pkg $want installed${RESET}"
    else
        echo -e "${RED}✖ $pkg build failed${RESET}"
    fi
    rm -rf "$build"
}

# Mouse pointer (Bibata Modern Ice). Replaces the old AUR package if present.
if pacman -Q bibata-cursor-theme &>/dev/null; then
    sudo pacman -Rdd --noconfirm bibata-cursor-theme
fi
install_local "Mouse pointer (Bibata)" bibata-cursor-zexos

# -----------------------------
# LOGIN MANAGER: SDDM PIXIE
# -----------------------------
# The theme's own package pulls in sddm and the Qt parts it needs.
# If the old AUR version is installed, swap it out first (--noconfirm
# would otherwise say "no" to replacing it).
if pacman -Q pixie-sddm-git &>/dev/null; then
    sudo pacman -Rdd --noconfirm pixie-sddm-git
fi
install_local "Login screen theme (Pixie)" pixie-sddm-zexos

echo -e "\n${YELLOW}[SDDM] Configuration${RESET}"

if [ -d /usr/share/sddm/themes/pixie ]; then

    sudo mkdir -p /etc/sddm.conf.d

    sudo tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=pixie
EOF

    echo -e "${GREEN}✔ Pixie theme configured${RESET}"

else
    echo -e "${RED}✖ Pixie theme directory not found${RESET}"
fi

# If the symlink doesn't exist at all (e.g. a genuinely fresh install with
# no display manager configured yet), `readlink` fails and the old
# `|| echo "none"` fallback never actually fired here — basename of an
# empty string is itself an empty string, not "none", which then made
# `sudo systemctl disable ""` run below and abort the whole script under
# `set -e`. Checking for the symlink explicitly first avoids that.
if [ -L /etc/systemd/system/display-manager.service ]; then
    CURRENT_DM=$(basename "$(readlink /etc/systemd/system/display-manager.service)" .service)
else
    CURRENT_DM="none"
fi

if [ "$CURRENT_DM" != "sddm" ]; then

    echo -e "${CYAN}Switching display manager from ${CURRENT_DM} to sddm${RESET}"

    [ "$CURRENT_DM" != "none" ] && sudo systemctl disable "$CURRENT_DM"

    sudo systemctl enable sddm

    echo -e "${GREEN}✔ SDDM enabled${RESET}"

else
    echo -e "${GREEN}✔ SDDM already active${RESET}"
fi


# -----------------------------
# QT6CT-KDE (dark theme for Dolphin, Gwenview)
# -----------------------------
# Plain qt6ct can't pass the colour scheme to KDE apps outside Plasma, so
# they stay bright white. This patched build can (see packaging/qt6ct-kde).
# It replaces plain qt6ct, so remove that first if something installed it.
if pacman -Q qt6ct &>/dev/null; then
    echo -e "${YELLOW}⚠ Removing plain qt6ct -- it clashes with qt6ct-kde${RESET}"
    sudo pacman -Rdd --noconfirm qt6ct
fi
install_local "Qt settings for KDE apps (qt6ct-kde)" qt6ct-kde

# =========================================================
# 3. FLATPAK / FLATHUB
# =========================================================

echo -e "\n${YELLOW}[FLATPAK] Setup${RESET}"

if ! command -v flatpak >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm flatpak &
    flatpak_install_pid=$!
    spinner "$flatpak_install_pid" "Installing Flatpak"

    if wait "$flatpak_install_pid"; then
        echo -e "${GREEN}✔ Flatpak installed${RESET}"
    else
        echo -e "${RED}✖ Failed to install Flatpak — remote/app steps below will also fail${RESET}"
    fi
fi

if ! flatpak remotes | grep -q flathub; then
    echo -e "${CYAN}Adding Flathub repository${RESET}"
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

FLATPAK_APPS=(
    com.github.tchx84.Flatseal
)

echo -e "\n${YELLOW}[FLATPAK] Applications${RESET}"

for app in "${FLATPAK_APPS[@]}"; do
    if flatpak list | grep -qi "$app"; then
        echo -e "${GREEN}✔ $app already installed${RESET}"
    else
        sudo flatpak install -y --system flathub "$app" || echo -e "${RED}✖ Failed to install $app${RESET}"
    fi
done

# -----------------------------
# DONE
# -----------------------------
echo -e "\n${GREEN}${BOLD}✔ PACKAGE INSTALL COMPLETE${RESET}"
echo -e "${BLUE}Log saved to: $LOGFILE${RESET}"
