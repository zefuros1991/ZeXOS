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
# The coloured ZeXOS logo at the top (see scripts/lib-banner.sh).
. "$REPO_ROOT/scripts/lib-banner.sh"
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
zexos_banner "ZeXOS PACKAGE INSTALLER"

echo -e "${VIOLET}GitHub: https://github.com/zefuros1991/ZeXOS${RESET}"
echo -e "${VIOLET}Log: $LOGFILE${RESET}"
echo -e "${VIOLET}--------------------------------------------------${RESET}"

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
    # No separate -debug packages (Arch turns them on), and no LTO: it makes
    # the final link slow and hungry for memory. A later entry wins.
    echo 'OPTIONS+=(!debug !lto)'
} > "$MAKEPKG_CONF_ZEXOS"
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true; rm -f "$MAKEPKG_CONF_ZEXOS"' EXIT

zexos_makepkg() {
    makepkg --config "$MAKEPKG_CONF_ZEXOS" "$@"
}

# Build on the disk, not in /tmp. Arch keeps /tmp in RAM (half of it), and
# linking noctalia needs more than that on a smaller machine: on a 6 GB VM
# it failed with "No space left on device". Each build folder is deleted
# when it's done.
ZEXOS_BUILD_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/zexos/build"
mkdir -p "$ZEXOS_BUILD_ROOT"
zexos_build_dir() {
    mktemp -d -p "$ZEXOS_BUILD_ROOT"
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
    neovim
    adw-gtk-theme
    fastfetch
    imagemagick
    ttf-jetbrains-mono-nerd
)

install_pacman "Desktop Core" "${CORE_PACMAN[@]}"

# -----------------------------
# DESKTOP BASICS
# -----------------------------
# What CachyOS's niri profile brings along and a KDE, GNOME or bare install
# may not have: portals (screen sharing, file dialogs), a password keyring,
# the clipboard tool, fonts, and the sound, network, Bluetooth and power
# services the bar talks to. KDE and GNOME installs already have most of
# these, so --needed skips them there. If one clashes with something you
# already use (say PulseAudio instead of PipeWire), pacman says no and your
# setup is kept; the bar just shows less for that one thing.
BASICS_PACMAN=(
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    gnome-keyring
    wl-clipboard
    noto-fonts
    noto-fonts-emoji
    xdg-user-dirs
    pipewire
    pipewire-pulse
    wireplumber
    networkmanager
    bluez
    bluez-utils
    power-profiles-daemon
    upower
    brightnessctl
    # checkupdates, which the bar's update counter needs. EndeavourOS and
    # CachyOS ship it; a plain Arch install does not.
    pacman-contrib
)

install_pacman "Desktop Basics" "${BASICS_PACMAN[@]}"

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
# to. Confirmed working under niri. Papirus is the icon theme; its folders
# are recoloured to follow the wallpaper (see make-papirus-zexos.py).
FILE_MANAGER_PACMAN=(
    dolphin
    kio-extras
    kde-cli-tools
    gwenview
    papirus-icon-theme
)

install_pacman "File Manager (Dolphin)" "${FILE_MANAGER_PACMAN[@]}"

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
    roller_build="$(zexos_build_dir)"
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
    noctalia_build="$(zexos_build_dir)"
    cp "$REPO_ROOT"/packaging/noctalia-zexos/* "$noctalia_build/"
    if (cd "$noctalia_build" && zexos_makepkg -s --noconfirm --needed); then
        # --noconfirm answers "no" to the conflict prompt, so drop stock first
        [ "$(pacman -Qq noctalia 2>/dev/null)" = "noctalia" ] && sudo pacman -Rdd --noconfirm noctalia
        sudo pacman -U --noconfirm "$noctalia_build"/noctalia-zexos-*.pkg.tar.zst
        echo -e "${GREEN}✔ noctalia-zexos $NOCTALIA_WANT installed${RESET}"
    else
        echo -e "${RED}✖ noctalia-zexos build failed -- stock noctalia kept, bar islands will float${RESET}"
    fi
    rm -rf "$noctalia_build"
fi

# -----------------------------
# DANKMATERIALSHELL (the second desktop shell)
# -----------------------------
# Installed next to Noctalia; Noctalia stays the default. Mod+Shift+D
# (`zshell menu`) switches between them, per user. dms-shell-niri pulls in
# the niri support, matugen makes the colours from the wallpaper.
# All three are in the Arch/CachyOS repos. dms-shell-niri goes first: on
# Arch, dms-shell needs "a compositor" package, and --noconfirm would
# otherwise pick the first one offered instead of the niri one.
DMS_PACMAN=(
    dms-shell-niri
    dms-shell
    matugen
)

install_pacman "DankMaterialShell" "${DMS_PACMAN[@]}"

# -----------------------------
# MANGO (a second compositor, picked at the login screen)
# -----------------------------
# Mango (mangowm) scrolls windows sideways like niri. It ships its own
# login-screen entry and portal settings. xdg-desktop-portal-wlr does screen
# sharing; grim, slurp and wl-clipboard do screenshots (zexos-screenshot).
# All in the Arch/CachyOS repos.
MANGO_PACMAN=(
    mangowm
    xdg-desktop-portal-wlr
    grim
    slurp
    wl-clipboard
)

install_pacman "Mango" "${MANGO_PACMAN[@]}"

# -----------------------------
# HYPRLAND (a third compositor, picked at the login screen)
# -----------------------------
# Hyprland tiles windows: each new one takes half of the one you're in.
# It ships its own login-screen entry. xdg-desktop-portal-hyprland does
# screen sharing; screenshots reuse Mango's grim, slurp and wl-clipboard.
# dms-shell-hyprland is DMS's Hyprland support. All in the Arch/CachyOS repos.
HYPR_PACMAN=(
    hyprland
    xdg-desktop-portal-hyprland
    dms-shell-hyprland
)

install_pacman "Hyprland" "${HYPR_PACMAN[@]}"

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
    build="$(zexos_build_dir)"
    cp "$REPO_ROOT/packaging/$dir"/* "$build/"
    if (cd "$build" && zexos_makepkg -si --noconfirm --needed); then
        echo -e "${GREEN}✔ $pkg $want installed${RESET}"
    else
        echo -e "${RED}✖ $pkg build failed${RESET}"
    fi
    rm -rf "$build"
}

# -----------------------------
# DISTRO-SPECIFIC STEPS
# -----------------------------
# The few things that differ between CachyOS and other Arch-based systems
# (the app store) live in scripts/distro/<name>.sh.
# lib-distro.sh works out which one to use; see the notes at its top.
. "$REPO_ROOT/scripts/lib-distro.sh"
zexos_detect_distro
if [ -r "$REPO_ROOT/scripts/distro/$ZEXOS_DISTRO.sh" ]; then
    echo -e "\n${YELLOW}[DISTRO] Steps for ${ZEXOS_DISTRO_NAME} (${ZEXOS_DISTRO})${RESET}"
    . "$REPO_ROOT/scripts/distro/$ZEXOS_DISTRO.sh"
else
    echo -e "${RED}✖ No distro steps for ${ZEXOS_DISTRO_NAME} (${ZEXOS_DISTRO_WHY:-$ZEXOS_DISTRO}) -- skipping them${RESET}"
fi

# Mouse pointer (Bibata Modern Ice). Replaces the old AUR package if present.
if [ "$(pacman -Qq bibata-cursor-theme 2>/dev/null)" = "bibata-cursor-theme" ]; then
    sudo pacman -Rdd --noconfirm bibata-cursor-theme
fi
install_local "Mouse pointer (Bibata)" bibata-cursor-zexos

# -----------------------------
# VIDEO WALLPAPER (mpvpaper)
# -----------------------------
# Plays the animated zexos-topo-energy wallpaper, through Noctalia's
# "Video Wallpaper" plugin. CachyOS has mpvpaper in its repos; plain Arch
# and EndeavourOS don't, so there it is built from packaging/mpvpaper.
# socat is optional: the plugin uses it to keep a video slideshow in step.
install_pacman "Video Wallpaper" mpv socat
if pacman -Si mpvpaper &>/dev/null; then
    install_pacman "Video Wallpaper (mpvpaper)" mpvpaper
else
    install_local "Video Wallpaper (mpvpaper)" mpvpaper
fi

# -----------------------------
# LOGIN MANAGER: SDDM PIXIE
# -----------------------------
# The theme's own package pulls in sddm and the Qt parts it needs.
# If the old AUR version is installed, swap it out first (--noconfirm
# would otherwise say "no" to replacing it).
if [ "$(pacman -Qq pixie-sddm-git 2>/dev/null)" = "pixie-sddm-git" ]; then
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

    # Another login screen may be in use (GDM on GNOME, Plasma Login on
    # newer KDE, ...). ZeXOS replaces it with SDDM + Pixie, but only once
    # everything the new one needs is really there: SDDM itself, the Pixie
    # theme, and the setting that picks it. Otherwise switching would swap a
    # working login screen for a broken one, so keep the old one instead.
    # (The login wallpaper sync is set up in finaltouches.sh.)
    pixie_ready=1
    for need in /usr/bin/sddm \
                /usr/share/sddm/themes/pixie/Main.qml \
                /usr/share/sddm/themes/pixie/metadata.desktop; do
        [ -e "$need" ] || { pixie_ready=0; echo -e "${RED}✖ Missing $need${RESET}"; }
    done
    grep -qx 'Current=pixie' /etc/sddm.conf.d/theme.conf 2>/dev/null || pixie_ready=0

    if [ "$pixie_ready" = 1 ]; then
        echo -e "${CYAN}Switching display manager from ${CURRENT_DM} to sddm${RESET}"
        [ "$CURRENT_DM" != "none" ] && sudo systemctl disable "$CURRENT_DM"
        sudo systemctl enable sddm
        echo -e "${GREEN}✔ SDDM with Pixie enabled${RESET}"
    else
        echo -e "${RED}✖ SDDM or the Pixie theme isn't ready, keeping ${CURRENT_DM} as the login screen${RESET}"
        echo -e "${CYAN}  Pick \"niri\" in its session list to start ZeXOS, and run install.sh again to retry${RESET}"
    fi

else
    echo -e "${GREEN}✔ SDDM already active${RESET}"
fi


# -----------------------------
# QT6CT-KDE (dark theme for Dolphin, Gwenview)
# -----------------------------
# Plain qt6ct can't pass the colour scheme to KDE apps outside Plasma, so
# they stay bright white. This patched build can (see packaging/qt6ct-kde).
# It replaces plain qt6ct, so remove that first if something installed it.
# `pacman -Q qt6ct` also answers "qt6ct-kde" (it stands in for qt6ct), so
# check the exact name, or a second run tries to remove a missing package.
if [ "$(pacman -Qq qt6ct 2>/dev/null)" = "qt6ct" ]; then
    echo -e "${YELLOW}⚠ Removing plain qt6ct -- it clashes with qt6ct-kde${RESET}"
    sudo pacman -Rdd --noconfirm qt6ct
fi
install_local "Qt settings for KDE apps (qt6ct-kde)" qt6ct-kde

# Qt updates can break qt6ct-kde, and pacman won't rebuild it for us (it
# isn't in any repo). This pacman hook rebuilds it in the background after
# every Qt update. See system/qt6ct-rebuild/.
if [ "$(pacman -Qq qt6ct-kde 2>/dev/null)" = "qt6ct-kde" ]; then
    rebuild_src="$REPO_ROOT/system/qt6ct-rebuild"
    sudo install -Dm755 "$rebuild_src/zexos-qt6ct-rebuild" /usr/local/lib/zexos/zexos-qt6ct-rebuild
    sudo install -Dm644 "$rebuild_src/zexos-qt6ct-rebuild.service" /etc/systemd/system/zexos-qt6ct-rebuild.service
    sudo install -Dm644 "$rebuild_src/zexos-qt6ct-rebuild.hook" /etc/pacman.d/hooks/zexos-qt6ct-rebuild.hook
    sudo install -d /etc/zexos
    printf 'ZEXOS_USER=%q\nZEXOS_REPO=%q\n' "$USER" "$REPO_ROOT" | sudo tee /etc/zexos/qt6ct-rebuild.conf >/dev/null
    sudo systemctl daemon-reload
    echo -e "${GREEN}✔ qt6ct-kde will rebuild itself after Qt updates${RESET}"
fi

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
