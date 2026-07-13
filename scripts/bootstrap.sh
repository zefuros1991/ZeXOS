#!/usr/bin/env bash
set -e

REPO="https://github.com/zefuros1991/ZeXOS.git"
TARGET="$HOME/.dotfiles"

# -----------------------------
# XDG environment (early)
# -----------------------------
# Set up XDG_* vars and dirs for THIS run before anything else touches the
# filesystem or installs packages. See scripts/lib-xdg.sh for why.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib-xdg.sh
. "$SCRIPT_DIR/lib-xdg.sh"
zexos_setup_xdg_env

LOGFILE="$TARGET/bootstrap.log"

# -----------------------------
# Logging
# -----------------------------
mkdir -p "$TARGET"
exec > >(tee -a "$LOGFILE") 2>&1

# -----------------------------
# Colors
# -----------------------------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# -----------------------------
# Spinner
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

clear

cat << "EOF"

███████╗███████╗██╗  ██╗ ██████╗ ███████╗
╚══███╔╝██╔════╝╚██╗██╔╝██╔═══██╗██╔════╝
  ███╔╝ █████╗   ╚███╔╝ ██║   ██║███████╗
 ███╔╝  ██╔══╝   ██╔██╗ ██║   ██║╚════██║
███████╗███████╗██╗  ██╗╚██████╔╝███████║
╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

        zeXOS BOOTSTRAP SYSTEM
--------------------------------------------------
EOF

echo -e "${BLUE}Project: ZeXOS Dotfiles Bootstrap${RESET}"
echo -e "${BLUE}GitHub:  ${REPO}${RESET}"
echo -e "${BLUE}Author:  Zefuros${RESET}"
echo -e "${BLUE}Contact: zefuros.certificates@gmail.com${RESET}"
echo "--------------------------------------------------"

echo -e "${BLUE}This script prepares the base system:${RESET}"
echo "  1. System update"
echo "  2. Core dependencies"
echo "  3. AUR helper (yay)"
echo "  4. Flatpak + Discover"
echo "  5. Clone repo to ~/.dotfiles"
echo "--------------------------------------------------"

# -----------------------------
# SUDO KEEPALIVE
# -----------------------------
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
# 1. SYSTEM UPDATE
# -----------------------------
echo -e "\n${YELLOW}==> [1/5] SYSTEM UPDATE${RESET}"
sudo pacman -Syu --noconfirm

cd "$HOME"

# -----------------------------
# 2. CORE DEPENDENCIES
# -----------------------------
echo -e "\n${YELLOW}==> [2/5] CORE DEPENDENCIES${RESET}"

sudo pacman -S --needed --noconfirm \
    git curl stow base-devel flatpak discover &
spinner $! "Installing core packages"

cd "$HOME"

# -----------------------------
# 3. AUR HELPER (yay)
# -----------------------------
echo -e "\n${YELLOW}==> [3/5] AUR HELPER (yay)${RESET}"

if command -v yay >/dev/null 2>&1; then
    echo -e "${GREEN}✔ yay already installed${RESET}"
else
    tmpdir=$(mktemp -d)

    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" &
    spinner $! "Cloning yay"

    cd "$tmpdir/yay"

    makepkg -si --noconfirm

    cd "$HOME"

    rm -rf "$tmpdir"

    echo -e "${GREEN}✔ yay installed${RESET}"
fi

# -----------------------------
# 4. FLATHUB SETUP
# -----------------------------
echo -e "\n${YELLOW}==> [4/5] FLATHUB SETUP${RESET}"

if flatpak remotes | grep -q flathub; then
    echo -e "${GREEN}✔ Flathub already configured${RESET}"
else
    flatpak remote-add --if-not-exists \
        flathub \
        https://flathub.org/repo/flathub.flatpakrepo

    echo -e "${GREEN}✔ Flathub added${RESET}"
fi

cd "$HOME"

# -----------------------------
# 5. REPOSITORY SETUP (CLEAN SOURCE OF TRUTH)
# -----------------------------
echo -e "\n${YELLOW}==> [5/5] REPOSITORY SETUP${RESET}"

OLD_REPO="$HOME/ZeXOS"

# If old manual clone exists, remove it to avoid confusion
if [ -d "$OLD_REPO" ]; then
    echo -e "${YELLOW}⚠ Found leftover ZeXOS folder, removing...${RESET}"
    rm -rf "$OLD_REPO"
    echo -e "${GREEN}✔ Old ZeXOS folder removed${RESET}"
fi

# Ensure target exists
mkdir -p "$TARGET"

# If dotfiles repo already exists, do nothing
if [ -d "$TARGET/.git" ]; then
    echo -e "${GREEN}✔ Repo already exists in ~/.dotfiles${RESET}"
else
    tmpclone=$(mktemp -d)

    git clone "$REPO" "$tmpclone/ZeXOS" &
    spinner $! "Cloning ZeXOS"

    cp -r "$tmpclone/ZeXOS"/. "$TARGET"

    rm -rf "$tmpclone"

    echo -e "${GREEN}✔ Repo installed into ~/.dotfiles${RESET}"
fi

cd "$TARGET"

# -----------------------------
# DONE
# -----------------------------
echo -e "\n${GREEN}${BOLD}✔ BOOTSTRAP COMPLETE${RESET}"
echo -e "${BLUE}Log saved to:${RESET} $LOGFILE"
echo -e "${CYAN}Next step:${RESET} run packages.sh"
