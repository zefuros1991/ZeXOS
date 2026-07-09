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
echo "--------------------------------------------------"

# -----------------------------
# 1. DEFAULT SHELL (ZSH)
# -----------------------------
echo -e "\n${YELLOW}==> [1/1] DEFAULT SHELL${RESET}"

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
# DONE
# -----------------------------
echo -e "\n${GREEN}${BOLD}✔ FINAL TOUCHES COMPLETE${RESET}"
echo -e "${BLUE}Log saved to:${RESET} $LOGFILE"
