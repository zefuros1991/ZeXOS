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
echo -e "${BLUE}Contact: zefuros.certificates@gmail.com${RESET}"
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
# GAMING
# -----------------------------
GAMING_PACMAN=(
    cachyos-gaming-meta
    cachyos-gaming-applications
    protonplus
    protontricks
    goverlay
)

install_pacman "Gaming Stack" "${GAMING_PACMAN[@]}"

# -----------------------------
# VIRTUALIZATION
# -----------------------------
VIRT_PACMAN=(
    qemu
    virt-manager
    libvirt
    dnsmasq
    ebtables
    iptables-nft
)

install_pacman "Virtualization" "${VIRT_PACMAN[@]}"

# -----------------------------
# DEVELOPMENT
# -----------------------------
DEV_PACMAN=(
    kitty
    alacritty
    vscodium
    obsidian
    neovim
)

install_pacman "Development Tools" "${DEV_PACMAN[@]}"

# -----------------------------
# SOCIAL
# -----------------------------
SOCIAL_PACMAN=(
    vesktop
)

install_pacman "Social Apps" "${SOCIAL_PACMAN[@]}"

# -----------------------------
# MEDIA
# -----------------------------
MEDIA_PACMAN=(
    spotify-launcher
    vlc
    obs-studio-browser
    ffmpeg
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
    libvorbis
    opus
    flac
    lame
)

install_pacman "Media Stack" "${MEDIA_PACMAN[@]}"

# -----------------------------
# SYSTEM
# -----------------------------
SYSTEM_PACMAN=(
    bitwarden
    gparted
    gedit
)

install_pacman "System Tools" "${SYSTEM_PACMAN[@]}"

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
# 2. AUR PACKAGES
# =========================================================

install_aur() {
    local label=$1
    shift
    local pkgs=("$@")

    echo -e "\n${YELLOW}[AUR] ${label}${RESET}"

    if ! command -v yay >/dev/null 2>&1; then
        echo -e "${RED}yay not installed (run bootstrap first)${RESET}"
        return
    fi

    for pkg in "${pkgs[@]}"; do
        if yay -Qi "$pkg" &>/dev/null; then
            echo -e "${GREEN}✔ $pkg already installed${RESET}"
        else
            echo -e "${CYAN}Installing $pkg${RESET}"

            yay -S --needed --noconfirm "$pkg" &
            spinner $! "Installing $pkg"

            if yay -Qi "$pkg" &>/dev/null; then
                echo -e "${GREEN}✔ $pkg installed successfully${RESET}"
            else
                echo -e "${RED}✖ Failed to install $pkg${RESET}"
            fi
        fi
    done
}

# -----------------------------
# SYSTEM (AUR)
# -----------------------------
SYSTEM_AUR=(
    monique
    btop
    xdg-ninja
    bibata-cursor-theme
)

install_aur "System Tools (AUR)" "${SYSTEM_AUR[@]}"

# -----------------------------
# LOGIN MANAGER: SDDM PIXIE
# -----------------------------
SDDM_PACMAN=(
    sddm
    qt6-declarative
    qt6-svg
    qt6-quickcontrols2
)

install_pacman "SDDM Pixie Dependencies" "${SDDM_PACMAN[@]}"

SDDM_AUR=(
    pixie-sddm-git
)

install_aur "SDDM Pixie Theme" "${SDDM_AUR[@]}"

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
# OTHER AUR
# -----------------------------
AUR_PACKAGES=(
    millennium
    spicetify
)

install_aur "AUR Extras" "${AUR_PACKAGES[@]}"

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
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

FLATPAK_APPS=(
    com.viber.Viber
    com.usebottles.bottles
    com.github.tchx84.Flatseal
)

echo -e "\n${YELLOW}[FLATPAK] Applications${RESET}"

for app in "${FLATPAK_APPS[@]}"; do
    if flatpak list | grep -qi "$app"; then
        echo -e "${GREEN}✔ $app already installed${RESET}"
    else
        flatpak install -y flathub "$app" || echo -e "${RED}✖ Failed to install $app${RESET}"
    fi
done

# -----------------------------
# DONE
# -----------------------------
echo -e "\n${GREEN}${BOLD}✔ PACKAGE INSTALL COMPLETE${RESET}"
echo -e "${BLUE}Log saved to: $LOGFILE${RESET}"
