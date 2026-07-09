#!/usr/bin/env bash
set -e

DOTFILES="$HOME/.dotfiles"
STOW_DIR="$DOTFILES/stow"
BACKUP_DIR="$DOTFILES/backup/stow-$(date +%Y%m%d-%H%M%S)"
LOGFILE="$DOTFILES/stow.log"

mkdir -p "$BACKUP_DIR"
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

clear

cat << "EOF"

███████╗███████╗██╗  ██╗ ██████╗ ███████╗
╚══███╔╝██╔════╝╚██╗██╔╝██╔═══██╗██╔════╝
  ███╔╝ █████╗   ╚███╔╝ ██║   ██║███████╗
 ███╔╝  ██╔══╝   ██╔██╗ ██║   ██║╚════██║
███████╗███████╗██╗  ██╗╚██████╔╝███████║
╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

        ZeXOS STOW SYSTEM
--------------------------------------------------
EOF

echo -e "${BLUE}Project: ZeXOS Dotfiles Stow Manager${RESET}"
echo -e "${BLUE}GitHub:  https://github.com/zefuros1991/ZeXOS${RESET}"
echo -e "${BLUE}Contact: zefuros.certificates@gmail.com${RESET}"
echo "--------------------------------------------------"

echo -e "${BLUE}Actions:${RESET}"
echo "  - Auto-detect stow packages"
echo "  - Skip already correctly linked files"
echo "  - Backup real file conflicts safely"
echo "--------------------------------------------------"

if [ ! -d "$STOW_DIR" ]; then
    echo -e "${RED}ERROR: stow directory not found: $STOW_DIR${RESET}"
    exit 1
fi

# -----------------------------
# PACKAGE LOOP
# -----------------------------
for pkg in "$STOW_DIR"/*; do
    [ -d "$pkg" ] || continue

    package_name=$(basename "$pkg")

    echo -e "\n${YELLOW}==> Package: $package_name${RESET}"

    # -------------------------
    # CHECK IF PACKAGE ALREADY PROPERLY STOWED
    # -------------------------
    if stow -d "$STOW_DIR" -t "$HOME" -n "$package_name" 2>&1 | grep -q "no conflicts"; then
        echo -e "${GREEN}✔ Already correctly stowed: $package_name${RESET}"
        continue
    fi

    # -------------------------
    # BACKUP CONFLICTS ONLY
    # -------------------------
    while IFS= read -r file; do
        target="$HOME/${file#$pkg/}"

        if [ -e "$target" ] && [ ! -L "$target" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "${file#$pkg/}")"
            mv "$target" "$BACKUP_DIR/${file#$pkg/}"

            echo -e "${YELLOW}⚠ Backed up:${RESET} $target"
        fi
    done < <(find "$pkg" -type f)

    # -------------------------
    # STOW PACKAGE
    # -------------------------
    stow -d "$STOW_DIR" -t "$HOME" "$package_name" &
    spinner $! "Stowing $package_name"

    echo -e "${GREEN}✔ Done: $package_name${RESET}"
done

echo -e "\n${GREEN}${BOLD}✔ STOW COMPLETE${RESET}"
echo -e "${BLUE}Backup:${RESET} $BACKUP_DIR"
echo -e "${BLUE}Log:${RESET} $LOGFILE"

