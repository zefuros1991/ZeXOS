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
# 0. MULTILIB REPOSITORY (defensive)
# -----------------------------
# Steam and the rest of the gaming stack installed later need 32-bit
# (lib32-*) packages, which only exist in the multilib repo. CachyOS's own
# niri/noctalia install profile enables this by default, but that's not
# guaranteed on every profile/distro this repo may end up running on -- and
# if it's ever off, every lib32-* package below fails outright with no
# useful error until Steam. Checking pacman.conf directly (not `pacman -Sl
# multilib`, which needs the repo already synced to answer) and enabling it
# before the first sync below if needed. Idempotent: no-op if already on.
echo -e "\n${YELLOW}==> [0/5] MULTILIB REPOSITORY${RESET}"

if grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo -e "${GREEN}✔ multilib already enabled${RESET}"
elif grep -q '^#\[multilib\]' /etc/pacman.conf; then
    echo -e "${CYAN}Enabling multilib repository${RESET}"
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    echo -e "${GREEN}✔ multilib enabled in /etc/pacman.conf${RESET}"
else
    echo -e "${RED}✖ Could not find a [multilib] section (commented or not) in /etc/pacman.conf -- lib32-* packages below will likely fail. Enable multilib by hand and re-run.${RESET}"
fi

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
core_pkgs_pid=$!
spinner "$core_pkgs_pid" "Installing core packages"

# These packages are load-bearing for the rest of this script (git/stow for
# the clone below, base-devel for the yay build just after) — the spinner
# used to print its checkmark regardless of whether the install actually
# succeeded, so a real failure here would silently look fine and then blow
# up confusingly a few steps later instead of here, where the real cause is
# obvious.
if wait "$core_pkgs_pid"; then
    echo -e "${GREEN}✔ Core packages installed${RESET}"
else
    echo -e "${RED}✖ Failed to install core packages — cannot continue without them${RESET}"
    exit 1
fi

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
    yay_clone_pid=$!
    spinner "$yay_clone_pid" "Cloning yay"

    # Same silently-swallowed-failure pattern as the core packages above:
    # without this check, a failed clone still printed a green checkmark,
    # then crashed on the next `cd` with a confusing "No such file or
    # directory" instead of a clear error.
    if ! wait "$yay_clone_pid"; then
        echo -e "${RED}✖ Failed to clone yay — cannot continue${RESET}"
        rm -rf "$tmpdir"
        exit 1
    fi

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
    repo_clone_pid=$!
    spinner "$repo_clone_pid" "Cloning ZeXOS"

    # Same check as the yay clone above — without it, a failed clone still
    # printed "Repo installed" and copied an empty directory into $TARGET,
    # leaving it without a .git folder (so the next run would just try the
    # same broken clone again instead of reporting what actually happened).
    if ! wait "$repo_clone_pid"; then
        echo -e "${RED}✖ Failed to clone ZeXOS repository${RESET}"
        rm -rf "$tmpclone"
        exit 1
    fi

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
