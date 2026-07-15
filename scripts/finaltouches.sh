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
echo -e "${BLUE}Author:  Zefuros${RESET}"
echo -e "${BLUE}Contact: zefuros.certificates@gmail.com${RESET}"
echo -e "${BLUE}Log:      $LOGFILE${RESET}"
echo "--------------------------------------------------"

echo -e "${BLUE}This script applies post-install tweaks:${RESET}"
echo "  1. Set zsh as default shell"
echo "  2. Repair Steam's bootstrap symlink if anything pre-seeded it"
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
# 2. STEAM BOOTSTRAP SELF-REPAIR
# -----------------------------
# Fixes a known first-launch failure: "Couldn't setup steam data - please
# contact technical support". Root cause (found 2026-07-08, see
# ~/AI/IssuesFixed/steam-couldnt-setup-steam-data.md): something -- a
# theming tool, a partial/interrupted install, matugen writing a wallpaper
# palette early -- creates ~/.steam/steam as a REAL directory before Steam
# ever launches, instead of leaving that path free for Steam's own
# bootstrap script to create as a symlink. Steam's self-repair logic then
# nests a new symlink *inside* that directory on every launch instead of
# replacing it, and can never satisfy its own check for
# ~/.steam/steam/steam.sh -- so the error shows up every single time.
#
# Running this as the last step of the whole install (after packages,
# stow, and any theming steps that might pre-seed the directory) means a
# fresh install ends in a clean state before the user ever launches Steam
# for the first time.
#
# Safe/idempotent: only acts if ~/.steam/steam exists as a real directory
# (not already the symlink Steam expects), and refuses to touch it if it
# looks like it holds actual Steam data (steamapps/userdata/compatdata) --
# prints a warning instead of deleting anything in that case.
echo -e "\n${YELLOW}==> [2/2] STEAM BOOTSTRAP CHECK${RESET}"

if [ -d "$HOME/.steam/steam" ] && [ ! -L "$HOME/.steam/steam" ]; then

    echo -e "${YELLOW}⚠ ~/.steam/steam is a real directory, not the symlink Steam expects${RESET}"

    if [ -d "$HOME/.steam/steam/steamapps" ] || [ -d "$HOME/.steam/steam/userdata" ] || [ -d "$HOME/.steam/steam/compatdata" ]; then
        echo -e "${RED}✖ Found what looks like real Steam data in there (steamapps/userdata/compatdata) -- leaving it alone, fix this one by hand${RESET}"
    else
        # Relocate any theming assets (e.g. Millennium skins) that may have
        # been pre-seeded here before Steam ever ran, to where the real
        # Steam install actually expects them once it exists.
        if [ -d "$HOME/.steam/steam/steamui/skins" ]; then
            mkdir -p "$HOME/.local/share/Steam/steamui/skins"
            for skin in "$HOME/.steam/steam/steamui/skins"/*; do
                [ -e "$skin" ] || continue
                cp -rn "$skin" "$HOME/.local/share/Steam/steamui/skins/" 2>/dev/null || true
            done
        fi

        rm -rf "$HOME/.steam/steam"
        echo -e "${GREEN}✔ Cleared the blocking directory -- Steam will create the correct symlink on next launch${RESET}"
    fi
else
    echo -e "${GREEN}✔ Steam bootstrap path OK (or Steam hasn't run yet)${RESET}"
fi

# -----------------------------
# DONE
# -----------------------------
echo -e "\n${GREEN}${BOLD}✔ FINAL TOUCHES COMPLETE${RESET}"
echo -e "${BLUE}Log saved to:${RESET} $LOGFILE"
