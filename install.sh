#!/usr/bin/env bash
set -e

REPO="https://github.com/zefuros1991/ZeXOS.git"
TARGET="$HOME/.dotfiles"

LOGFILE="$HOME/.dotfiles/install.log"

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

```
echo -ne "${CYAN}${msg}${RESET} "

while kill -0 "$pid" 2>/dev/null; do
    for i in $(seq 0 3); do
        echo -ne "\b${spin:$i:1}"
        sleep 0.1
    done
done

echo -e "\b✔"
```

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
echo -e "${BLUE}Author:  Zefuros${RESET}"
echo -e "${BLUE}Contact: [zefuros.certificates@gmail.com](mailto:zefuros.certificates@gmail.com)${RESET}"
echo "--------------------------------------------------"

echo -e "${BLUE}This installer performs:${RESET}"
echo "  1. Bootstrap system"
echo "  2. Install packages"
echo "  3. Deploy dotfiles"
echo "  4. Complete ZeXOS setup"
echo "  5. Complete ZeXOS setup"
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

```
tmpclone=$(mktemp -d)

git clone "$REPO" "$tmpclone/ZeXOS" &
spinner $! "Cloning repository"

mkdir -p "$TARGET"
cp -r "$tmpclone/ZeXOS"/. "$TARGET"

rm -rf "$tmpclone"

echo -e "${GREEN}✔ Repository installed${RESET}"
```

else
echo -e "${GREEN}✔ Repository already present${RESET}"
fi

# -----------------------------

# BOOTSTRAP

# -----------------------------

echo -e "\n${YELLOW}==> [1/3] BOOTSTRAP${RESET}"

bash "$TARGET/scripts/bootstrap.sh"

# -----------------------------

# PACKAGES

# -----------------------------

echo -e "\n${YELLOW}==> [2/3] PACKAGE INSTALLATION${RESET}"

bash "$TARGET/scripts/packages.sh"

# -----------------------------

# STOW

# -----------------------------

echo -e "\n${YELLOW}==> [3/3] DOTFILE DEPLOYMENT${RESET}"

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
