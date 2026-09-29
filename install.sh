#!/usr/bin/env bash
set -e

REPO="https://github.com/zefuros1991/ZeXOS.git"
# Which branch to install. Always main, unless you are testing a new
# change: ZEXOS_BRANCH=<branch> bash install.sh
BRANCH="${ZEXOS_BRANCH:-main}"
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

# -----------------------------

# Banner

# -----------------------------

# The ZeXOS logo in the colours of docs/logo/zexos-mark.svg (violet ->
# purple -> green). This is a copy of scripts/lib-banner.sh, because on a
# first install this script is downloaded on its own and the repo isn't
# there yet: change both together. The one extra here is the animation:
# while sudo waits for the password, the colours slowly flow through the
# logo. Terminals that can't show exact colours get basic ones, no animation.

ZEXOS_BANNER_ROWS=(
'███████╗        ██╗    ███╗  ██████╗  ██████╗'
'╚══███╔╝ ████╗  ╚═██╗  ╚══╝ ██╔═══██╗██╔════╝'
'  ███╔╝ ██╔═██╗   ╚████╗    ██║   ██║╚█████╗ '
' ███╔╝  █████╔╝    ╚══██╗   ██║   ██║ ╚═══██╗'
'███████╗╚█████╗ ███╗  ╚═██╗ ╚██████╔╝██████╔╝'
'╚══════╝ ╚════╝ ╚══╝    ╚═╝  ╚═════╝ ╚═════╝ '
)

case "$COLORTERM" in
    truecolor|24bit) ZEXOS_TRUECOLOR=1 ;;
    *) ZEXOS_TRUECOLOR=0 ;;
esac

if [ "$ZEXOS_TRUECOLOR" = 1 ]; then
    VIOLET="\e[38;2;154;92;242m"
else
    VIOLET="\e[95m"
fi

# 64 colours: violet to purple to green (0-32), then back again (33-63), so
# the animation can loop without a jump. Stops: #7C5CFF, #B45CE6, #3DDC97.
ZEXOS_PALETTE=()
for (( i = 0; i < 64; i++ )); do
    s=$(( i <= 32 ? i : 64 - i ))
    if [ "$ZEXOS_TRUECOLOR" != 1 ]; then
        if [ "$s" -lt 11 ]; then c=$'\e[94m'; elif [ "$s" -lt 22 ]; then c=$'\e[95m'; else c=$'\e[92m'; fi
    else
        if [ "$s" -le 16 ]; then a=(124 92 255); b=(180 92 230); t=$s
        else a=(180 92 230); b=(61 220 151); t=$((s - 16)); fi
        c=$'\e[38;2;'"$(( a[0] + (b[0] - a[0]) * t / 16 ));$(( a[1] + (b[1] - a[1]) * t / 16 ));$(( a[2] + (b[2] - a[2]) * t / 16 ))m"
    fi
    ZEXOS_PALETTE[i]=$c
done

# Logo row $1 at animation step $2 (0 = still), in REPLY. The colour runs
# diagonally from the top left, and each step moves it one place along.
zexos_banner_row() {
    local LC_ALL=C.UTF-8
    local row=${ZEXOS_BANNER_ROWS[$1]} out="" i ch
    for (( i = 0; i < ${#row}; i++ )); do
        ch=${row:i:1}
        if [ "$ch" = " " ]; then out+=" "; continue; fi
        out+="${ZEXOS_PALETTE[( (i + 2 * $1) * 32 / 55 - $2 ) & 63]}$ch"
    done
    REPLY="$out"$'\e[0m'
}

# Repaints the logo in place (it starts on screen line 2, under the blank
# line after `clear`) without moving the cursor away from the password
# prompt. Each row goes out in one write, so it can't split sudo's output.
zexos_banner_paint() {
    local r
    for r in "${!ZEXOS_BANNER_ROWS[@]}"; do
        zexos_banner_row "$r" "$1"
        printf '\e7\e[%d;1H%s\e8' $((r + 2)) "$REPLY"
    done
}

zexos_banner_animate() {
    local f=0
    while kill -0 "$1" 2>/dev/null; do
        f=$(( (f + 1) & 63 ))
        zexos_banner_paint "$f"
        sleep 0.06
    done
}

clear

echo
for r in "${!ZEXOS_BANNER_ROWS[@]}"; do
    zexos_banner_row "$r" 0
    printf '%s\n' "$REPLY"
done
echo
echo -e "${VIOLET}        ZeXOS INSTALLATION SYSTEM"
echo -e "--------------------------------------------------${RESET}"

echo -e "${VIOLET}Project: ZeXOS Complete Installer${RESET}"
echo -e "${VIOLET}GitHub:  ${REPO}${RESET}"
echo -e "${VIOLET}--------------------------------------------------${RESET}"

echo -e "${VIOLET}This installer performs:${RESET}"
echo -e "${VIOLET}  1. Bootstrap system${RESET}"
echo -e "${VIOLET}  2. Install packages${RESET}"
echo -e "${VIOLET}  3. Deploy dotfiles${RESET}"
echo -e "${VIOLET}  4. Final touches (wallpapers, login wallpaper)${RESET}"
echo -e "${VIOLET}--------------------------------------------------${RESET}"

# -----------------------------

# AUTHENTICATION

# -----------------------------

echo -e "\n${YELLOW}==> AUTHENTICATION${RESET}"

# The logo breathes while the password is asked for. If sudo still
# remembers the password (no prompt), it breathes for a couple of seconds
# anyway before the install starts. Only when the whole banner fits on
# screen, even after a few wrong passwords (if it scrolled, the repaint
# would land on the wrong lines).
animate=0
if [ "$ZEXOS_TRUECOLOR" = 1 ] && [ -t 0 ] && [ -t 1 ]; then
    read -r rows cols < <(stty size </dev/tty 2>/dev/null) || true
    if [ "${rows:-0}" -ge 28 ] && [ "${cols:-0}" -ge 45 ]; then
        animate=1
    fi
fi

rc=0
if [ "$animate" = 1 ]; then
    zexos_banner_animate $$ &
    banner_pid=$!
    # A background job ignores Ctrl+C, so stop it by hand if we're interrupted.
    trap 'kill $banner_pid 2>/dev/null' EXIT
    trap 'exit 130' INT
    if sudo -n true 2>/dev/null; then
        sleep 3
    else
        sudo -v || rc=$?
    fi
    kill "$banner_pid" 2>/dev/null || true
    wait "$banner_pid" 2>/dev/null || true
    trap - EXIT INT
    zexos_banner_paint 0
else
    sudo -v || rc=$?
fi
[ "$rc" -eq 0 ] || exit "$rc"

# -----------------------------

# Logging

# -----------------------------

# Starts only after the password prompt. sudo writes its prompt straight
# to the screen, while everything else goes through tee first, so with
# logging on the prompt could land out of order and get hidden.
mkdir -p "$HOME/.dotfiles"
exec > >(tee -a "$LOGFILE") 2>&1

(
while true; do
sudo -n true
sleep 50
done
) &

SUDO_KEEPALIVE_PID=$!

trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

# A minimal Arch install doesn't come with git, and the next step needs it.
if ! command -v git >/dev/null 2>&1; then
    echo -e "${CYAN}Installing git${RESET}"
    if ! sudo pacman -S --needed --noconfirm git; then
        echo -e "${RED}✖ Could not install git, which is needed to download ZeXOS${RESET}"
        exit 1
    fi
fi

# -----------------------------

# REPOSITORY CHECK

# -----------------------------

echo -e "\n${YELLOW}==> REPOSITORY CHECK${RESET}"

if [ ! -d "$TARGET/.git" ]; then
echo -e "${CYAN}Cloning ZeXOS repository${RESET}"

tmpclone=$(mktemp -d)

git clone -b "$BRANCH" "$REPO" "$tmpclone/ZeXOS" &
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
#
# Noctalia rewrites the colour files in the repo on every wallpaper change,
# so git sees them as your edits, and one the update also changes would
# block it. Only those get put back to the repo's version first (a copy
# goes to backup/); noctalia paints your colours over them again at the end.
NOCTALIA_WRITES=(
    stow/btop/.config/btop/btop.conf
    stow/btop/.config/btop/themes/noctalia.theme
    stow/desktop/.config/kdeglobals
    stow/fuzzel/.config/fuzzel/fuzzel.ini
    stow/fuzzel/.config/fuzzel/themes/noctalia
    stow/kitty/.config/kitty/kitty.conf
    stow/kitty/.config/kitty/themes/noctalia.conf
    stow/niri/.config/niri/config.kdl
    stow/niri/.config/niri/noctalia.kdl
    stow/theme/.config/gtk-3.0/noctalia.css
    stow/theme/.config/gtk-4.0/noctalia.css
    stow/theme/.config/qt5ct/colors/noctalia.conf
    stow/theme/.config/qt6ct/colors/noctalia.conf
)
if git -C "$TARGET" fetch -q 2>/dev/null; then
    color_backup="$TARGET/backup/update-$(date +%Y%m%d-%H%M%S)"
    for f in $(git -C "$TARGET" diff --name-only HEAD '@{u}' -- "${NOCTALIA_WRITES[@]}"); do
        git -C "$TARGET" diff --quiet HEAD -- "$f" && continue
        mkdir -p "$color_backup/$(dirname "$f")"
        cp "$TARGET/$f" "$color_backup/$f"
        git -C "$TARGET" checkout -q HEAD -- "$f"
        echo -e "${CYAN}Put back $f for the update (your copy: $color_backup/$f)${RESET}"
    done
fi
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

# DISTRO CHECK

# -----------------------------

# Works out whether this is CachyOS, plain Arch or a close relative, and
# stops here with the reason if ZeXOS can't support it. Later steps use
# the answer to pick scripts/distro/<name>.sh. See scripts/lib-distro.sh.
. "$TARGET/scripts/lib-distro.sh"
zexos_require_supported_distro || exit 1

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

# On an update with the desktop running, repaint the colour files with the
# current wallpaper's colours (the update may have put some of them back).
if pgrep -x noctalia >/dev/null 2>&1; then
    noctalia msg templates-apply >/dev/null 2>&1 || true
fi

# -----------------------------
# DONE
# -----------------------------

echo -e "\n${GREEN}${BOLD}✔ ZEXOS INSTALLATION COMPLETE${RESET}"
echo -e "${BLUE}Log saved to:${RESET} $LOGFILE"
echo -e "${CYAN}Reboot recommended.${RESET}"
