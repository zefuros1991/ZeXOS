#!/usr/bin/env bash
set -e

REPO="https://github.com/zefuros1991/ZeXOS.git"
TARGET="$HOME/.dotfiles"

LOGFILE="$HOME/.dotfiles/install.log"

# -----------------------------

# Preflight

# -----------------------------

# ZeXOS installs everything with pacman, so it only works on Arch-based
# systems (CachyOS, Arch, EndeavourOS, ...). The desktop you start from
# doesn't matter: KDE, GNOME or none at all. It must run as your normal
# user, not root, because it sets up your home folder.
if ! command -v pacman >/dev/null 2>&1; then
    echo "ZeXOS needs an Arch-based system with pacman (CachyOS, Arch, EndeavourOS, ...). Stopping." >&2
    exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
    echo "Run the installer as your normal user, not as root or with sudo. It asks for your password when it needs it." >&2
    exit 1
fi

# -----------------------------

# Logging

# -----------------------------

mkdir -p "$HOME/.dotfiles"
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
local spin='|/-'

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

        ZeXOS INSTALLATION SYSTEM
--------------------------------------------------
EOF

echo -e "${BLUE}Project: ZeXOS Complete Installer${RESET}"
echo -e "${BLUE}GitHub:  ${REPO}${RESET}"
echo "--------------------------------------------------"

echo -e "${BLUE}This installer performs:${RESET}"
echo "  1. Bootstrap system"
echo "  2. Install packages"
echo "  3. Deploy dotfiles"
echo "  4. Final touches (default shell, login wallpaper)"
echo "--------------------------------------------------"

# -----------------------------

# AUTHENTICATION

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

# REPOSITORY CHECK

# -----------------------------

echo -e "\n${YELLOW}==> REPOSITORY CHECK${RESET}"

if [ ! -d "$TARGET/.git" ]; then
echo -e "${CYAN}Cloning ZeXOS repository${RESET}"

tmpclone=$(mktemp -d)

git clone "$REPO" "$tmpclone/ZeXOS" &
repo_clone_pid=$!
spinner "$repo_clone_pid" "Cloning repository"

# Without this check, a failed clone (network hiccup, etc.) still printed
# "Repository installed" and copied an empty directory into $TARGET, which
# then crashed a few lines below when sourcing scripts/lib-xdg.sh from a
# $TARGET that never actually got the repo.
if ! wait "$repo_clone_pid"; then
    echo -e "${RED}✖ Failed to clone ZeXOS repository${RESET}"
    rm -rf "$tmpclone"
    exit 1
fi

mkdir -p "$TARGET"
cp -r "$tmpclone/ZeXOS"/. "$TARGET"

rm -rf "$tmpclone"

echo -e "${GREEN}✔ Repository installed${RESET}"

else
# Already installed: fetch the newest version so running install.sh again
# works as an update. --ff-only refuses to touch your own local edits;
# if you have some, the install carries on with what you have.
if git -C "$TARGET" pull --ff-only -q; then
    echo -e "${GREEN}✔ Repository already present, updated to the newest version${RESET}"
else
    echo -e "${YELLOW}Repository already present, but could not update it (local changes or no network). Using it as it is.${RESET}"
fi
fi

# -----------------------------

# XDG ENVIRONMENT (early, propagated to every stage below)

# -----------------------------

# Source the shared helper and export the XDG_* vars into THIS process now,
# before calling any stage script. Every "bash scripts/X.sh" call below
# inherits exported variables automatically, so bootstrap/packages/stow all
# see the same XDG_CONFIG_HOME/XDG_CACHE_HOME/XDG_DATA_HOME/XDG_STATE_HOME
# (and the directories already existing) from the very first step, instead
# of only after the next login. See scripts/lib-xdg.sh for the full reasoning.
. "$TARGET/scripts/lib-xdg.sh"
zexos_setup_xdg_env

# -----------------------------

# BOOTSTRAP

# -----------------------------

echo -e "\n${YELLOW}==> [1/4] BOOTSTRAP${RESET}"

bash "$TARGET/scripts/bootstrap.sh"

# -----------------------------

# PACKAGES

# -----------------------------

echo -e "\n${YELLOW}==> [2/4] PACKAGE INSTALLATION${RESET}"

bash "$TARGET/scripts/packages.sh"

# -----------------------------

# STOW

# -----------------------------

echo -e "\n${YELLOW}==> [3/4] DOTFILE DEPLOYMENT${RESET}"

bash "$TARGET/scripts/stow.sh"

# -----------------------------
# FINAL TOUCHES
# -----------------------------

echo -e "\n${YELLOW}==> [4/4] FINAL TOUCHES${RESET}"

bash "$TARGET/scripts/finaltouches.sh"

# -----------------------------
# DONE
# -----------------------------

echo -e "\n${GREEN}${BOLD}✔ ZEXOS INSTALLATION COMPLETE${RESET}"
echo -e "${BLUE}Log saved to:${RESET} $LOGFILE"
echo -e "${CYAN}Reboot recommended.${RESET}"
