#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The coloured ZeXOS logo at the top (see scripts/lib-banner.sh).
. "$REPO_ROOT/scripts/lib-banner.sh"

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

zexos_banner "ZeXOS FINAL TOUCHES"

echo -e "${VIOLET}Project: ZeXOS Final Touches${RESET}"
echo -e "${VIOLET}Log:      $LOGFILE${RESET}"
echo -e "${VIOLET}--------------------------------------------------${RESET}"

echo -e "${VIOLET}This script applies post-install tweaks:${RESET}"
echo -e "${VIOLET}  1. Copy the ZeXOS wallpapers to ~/Pictures/Wallpapers${RESET}"
echo -e "${VIOLET}  2. Wire up SDDM login wallpaper sync (pixie theme)${RESET}"
echo -e "${VIOLET}--------------------------------------------------${RESET}"

# -----------------------------
# 1. WALLPAPERS
# -----------------------------
# Noctalia and roller both read ~/Pictures/Wallpapers, and noctalia.toml
# names zexos-aurora.jpg as the starting wallpaper. --update=none never replaces a
# file that is already there, so your own pictures are safe.
echo -e "\n${YELLOW}==> [1/2] WALLPAPERS${RESET}"

WALL_SRC="$REPO_ROOT/wallpapers"
WALL_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALL="$WALL_DIR/zexos-aurora.jpg"

mkdir -p "$WALL_DIR"
cp --update=none "$WALL_SRC"/*.jpg "$WALL_DIR"/
echo -e "${GREEN}✔ ZeXOS wallpapers are in $WALL_DIR${RESET}"

# The animated wallpapers go in their own folder, where roller shows them as
# a separate group (Mod+Shift+W, or Tab inside the picker) and Noctalia's
# Video Wallpaper plugin looks for them (noctalia.toml). None is switched
# on: a looping 4K video is a steady small load, so you pick one yourself.
VIDEO_DIR="$WALL_DIR/Animated"
mkdir -p "$VIDEO_DIR"
cp --update=none "$WALL_SRC"/*.mp4 "$VIDEO_DIR"/
echo -e "${GREEN}✔ Animated wallpapers are in $VIDEO_DIR (Mod+Shift+W picks one)${RESET}"

# GTK 4 apps get the adw-gtk3 dark look through two links to the installed
# theme. They point at absolute system paths, which stow refuses to deploy,
# so they're made here instead of living in the repo.
ADW_GTK4="/usr/share/themes/adw-gtk3/gtk-4.0"
if [ -d "$ADW_GTK4" ]; then
    mkdir -p "$HOME/.config/gtk-4.0"
    ln -sfn "$ADW_GTK4/assets" "$HOME/.config/gtk-4.0/assets"
    ln -sfn "$ADW_GTK4/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
    echo -e "${GREEN}✔ GTK 4 apps linked to the adw-gtk3 theme${RESET}"
else
    echo -e "${RED}✖ adw-gtk3 not found at $ADW_GTK4, skipping the GTK 4 theme links${RESET}"
fi

# Papirus with folders that follow the wallpaper colour. Built now so the
# first Dolphin window already has it; afterwards every wallpaper change
# rebuilds it when Papirus was updated (see make-papirus-zexos.py).
if "$HOME/.local/bin/make-papirus-zexos.py"; then
    echo -e "${GREEN}✔ Folder icons follow the wallpaper colour (Papirus-ZeXOS)${RESET}"
else
    echo -e "${RED}✖ Could not build the Papirus-ZeXOS folder icons${RESET}"
fi

# Point Qt, KDE, GTK, fuzzel and btop colours at the shell in use (see
# `zshell relink`), and start the watcher that keeps them in step with
# DankMaterialShell's colours when DMS is the shell (it does nothing under
# Noctalia, which handles this itself).
if "$HOME/.local/bin/zshell" relink; then
    echo -e "${GREEN}✔ App colours follow the desktop shell in use${RESET}"
else
    echo -e "${RED}✖ zshell relink failed${RESET}"
fi
if systemctl --user daemon-reload && systemctl --user enable --now zexos-dms-sync.path >/dev/null 2>&1; then
    echo -e "${GREEN}✔ DankMaterialShell colour watcher on (zexos-dms-sync.path)${RESET}"
elif [ ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]; then
    # No user session running (the installer ISO runs this inside the new
    # system before its first boot), so systemctl can't reach it. Make the
    # same link "enable" would; it starts at your first login.
    wants="$HOME/.config/systemd/user/default.target.wants"
    mkdir -p "$wants"
    ln -sf ../zexos-dms-sync.path "$wants/zexos-dms-sync.path"
    echo -e "${GREEN}✔ DankMaterialShell colour watcher starts at first login${RESET}"
else
    echo -e "${RED}✖ Could not turn on zexos-dms-sync.path${RESET}"
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

    # Give the login screen the same picture as the desktop right away.
    # Without one, Pixie shows its own default until the first wallpaper
    # change. A plain copy is enough: the default is already a JPEG.
    # Noctalia saves the wallpapers you pick in its settings.toml; if there
    # is none there, you are still on the default, so the login screen
    # should be too (this also fixes older installs that got Pixie's picture).
    NOCTALIA_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"
    if [ ! -f "$SDDM_WALLPAPER_DIR/current.jpg" ] || ! grep -q '^\[wallpaper' "$NOCTALIA_STATE" 2>/dev/null; then
        if cp "$DEFAULT_WALL" "$SDDM_WALLPAPER_DIR/current.jpg"; then
            echo -e "${GREEN}✔ Login background set to $(basename "$DEFAULT_WALL")${RESET}"
        else
            echo -e "${RED}✖ Could not set a first login background${RESET}"
        fi
    fi

    # The round avatar above the login box, in the wallpaper's colours.
    # Pixie's avatar.jpg links here; the package puts the violet one here
    # first, this only covers a folder that was set up before that.
    if [ ! -f "$SDDM_WALLPAPER_DIR/avatar.jpg" ] && [ -f "$PIXIE_THEME_DIR/assets/avatars/violet.jpg" ]; then
        cp "$PIXIE_THEME_DIR/assets/avatars/violet.jpg" "$SDDM_WALLPAPER_DIR/avatar.jpg" \
            && echo -e "${GREEN}✔ Login avatar set${RESET}"
    fi

    echo -e "${CYAN}Login background and avatar update on every wallpaper change and shell switch${RESET}"
fi

# -----------------------------
# DONE
# -----------------------------
echo -e "\n${GREEN}${BOLD}✔ FINAL TOUCHES COMPLETE${RESET}"
echo -e "${BLUE}Log saved to:${RESET} $LOGFILE"
