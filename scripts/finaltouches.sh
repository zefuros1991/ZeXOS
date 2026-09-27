#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOGFILE="$REPO_ROOT/finaltouches.log"

# -----------------------------
# Logging
# -----------------------------
mkdir -p "$REPO_ROOT"
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

        ZeXOS FINAL TOUCHES
--------------------------------------------------
EOF

echo -e "${BLUE}Project: ZeXOS Final Touches${RESET}"
echo -e "${BLUE}Log:      $LOGFILE${RESET}"
echo "--------------------------------------------------"

echo -e "${BLUE}This script applies post-install tweaks:${RESET}"
echo "  1. Set zsh as default shell"
echo "  2. Wire up SDDM login wallpaper sync (pixie theme)"
echo "--------------------------------------------------"

# -----------------------------
# 1. DEFAULT SHELL (ZSH)
# -----------------------------
echo -e "\n${YELLOW}==> [1/2] DEFAULT SHELL${RESET}"

if command -v zsh >/dev/null 2>&1; then

    CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

    if [ "$CURRENT_SHELL" != "$(command -v zsh)" ]; then

        chsh -s "$(command -v zsh)"

        echo -e "${GREEN}✔ Default shell changed to zsh${RESET}"
        echo -e "${CYAN}Log out and back in for the change to take effect${RESET}"

    else
        echo -e "${GREEN}✔ zsh already configured as default shell${RESET}"
    fi

else
    echo -e "${RED}✖ zsh is not installed${RESET}"
fi

# -----------------------------
# 2. SDDM LOGIN WALLPAPER SYNC (PIXIE THEME)
# -----------------------------
# noctalia's wallpaper_changed hook ([hooks] in stow/noctalia/.config/noctalia/noctalia.toml)
# calls stow/noctalia/.local/bin/sync-sddm-wallpaper.sh on every wallpaper
# change, which mirrors the active wallpaper into
# /var/lib/sddm-wallpaper/current.jpg so the SDDM login screen matches the
# desktop. That script runs as the regular user (it's a desktop hook, not a
# privileged one), so the destination directory has to already exist and be
# user-writable, and the pixie theme has to be pointed at it -- neither of
# which the pixie-sddm-zexos package sets up on its own. Runs here (last, after
# packages.sh installed the pixie theme and stow deployed the sync script)
# so a fresh install ends with login-screen sync already working, instead of
# silently no-op'ing until someone notices and fixes it by hand.
#
# Safe/idempotent: only touches the wallpaper dir and theme.conf.user if
# they're not already set up correctly.
echo -e "\n${YELLOW}==> [2/2] SDDM WALLPAPER SYNC${RESET}"

SDDM_WALLPAPER_DIR="/var/lib/sddm-wallpaper"
PIXIE_THEME_DIR="/usr/share/sddm/themes/pixie"
PIXIE_USER_CONF="$PIXIE_THEME_DIR/theme.conf.user"

if [ ! -d "$PIXIE_THEME_DIR" ]; then
    echo -e "${RED}✖ Pixie SDDM theme not found at $PIXIE_THEME_DIR -- skipping (did packages.sh run?)${RESET}"
elif ! command -v magick >/dev/null 2>&1; then
    echo -e "${RED}✖ ImageMagick ('magick') not found -- sync-sddm-wallpaper.sh depends on it, skipping${RESET}"
else
    if [ -d "$SDDM_WALLPAPER_DIR" ] && [ "$(stat -c %U "$SDDM_WALLPAPER_DIR")" = "$USER" ]; then
        echo -e "${GREEN}✔ $SDDM_WALLPAPER_DIR already exists and is user-writable${RESET}"
    else
        sudo mkdir -p "$SDDM_WALLPAPER_DIR"
        sudo chown "$USER:$USER" "$SDDM_WALLPAPER_DIR"
        sudo chmod 755 "$SDDM_WALLPAPER_DIR"
        echo -e "${GREEN}✔ Created $SDDM_WALLPAPER_DIR (owned by $USER)${RESET}"
    fi

    if [ -f "$PIXIE_USER_CONF" ] && grep -q "^background=$SDDM_WALLPAPER_DIR/current.jpg$" "$PIXIE_USER_CONF"; then
        echo -e "${GREEN}✔ Pixie theme already points to $SDDM_WALLPAPER_DIR/current.jpg${RESET}"
    else
        sudo tee "$PIXIE_USER_CONF" >/dev/null <<EOF
[General]
background=$SDDM_WALLPAPER_DIR/current.jpg
EOF
        echo -e "${GREEN}✔ Pointed pixie theme at $SDDM_WALLPAPER_DIR/current.jpg${RESET}"
    fi

    echo -e "${CYAN}Login background updates on the next desktop wallpaper change${RESET}"
fi

# -----------------------------
# DONE
# -----------------------------
echo -e "\n${GREEN}${BOLD}✔ FINAL TOUCHES COMPLETE${RESET}"
echo -e "${BLUE}Log saved to:${RESET} $LOGFILE"
