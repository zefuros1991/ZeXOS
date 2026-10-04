#!/usr/bin/env bash
set -e

# -----------------------------
# CONFIG
# -----------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------
# XDG environment (defensive)
# -----------------------------
# Normally already exported by install.sh/bootstrap.sh before this script
# runs, but set it up here too in case packages.sh is ever run on its own.
# Idempotent — see scripts/lib-xdg.sh.
. "$REPO_ROOT/scripts/lib-xdg.sh"
# The coloured ZeXOS logo at the top (see scripts/lib-banner.sh).
. "$REPO_ROOT/scripts/lib-banner.sh"
zexos_setup_xdg_env

LOGFILE="$REPO_ROOT/packages.log"
mkdir -p "$REPO_ROOT"
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

# -----------------------------
# ASCII HEADER
# -----------------------------
clear
zexos_banner "ZeXOS PACKAGE INSTALLER"

echo -e "${VIOLET}GitHub: https://github.com/zefuros1991/ZeXOS${RESET}"
echo -e "${VIOLET}Log: $LOGFILE${RESET}"
echo -e "${VIOLET}--------------------------------------------------${RESET}"

# -----------------------------
# SUDO KEEPALIVE (standalone safety)
# -----------------------------
# This script needs sudo for every pacman call plus the SDDM setup below.
# Normally install.sh already keeps sudo warm for the whole run, so this
# `sudo -v` is a harmless no-op refresh in that case. When packages.sh is
# run standalone with a cold sudo cache, this prompts once up front instead
# of leaving that to whichever backgrounded pacman call happens to need it
# first.
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

# makepkg normally calls "sudo -k", which forgets the password on purpose
# and asks for it again each time it installs something. This wrapper runs
# makepkg with a copy of your normal settings plus PACMAN_AUTH=(sudo), so it
# uses the password you already typed at the start.
MAKEPKG_CONF_ZEXOS="$(mktemp)"
{
    cat /etc/makepkg.conf
    cat /etc/makepkg.conf.d/*.conf 2>/dev/null || true
    # Your own makepkg.conf, if you have one (most people don't).
    cat "${XDG_CONFIG_HOME:-$HOME/.config}/pacman/makepkg.conf" 2>/dev/null \
        || cat "$HOME/.makepkg.conf" 2>/dev/null || true
    echo 'PACMAN_AUTH=(sudo)'
    # No separate -debug packages (Arch turns them on), and no LTO: it makes
    # the final link slow and hungry for memory. A later entry wins.
    echo 'OPTIONS+=(!debug !lto)'
} > "$MAKEPKG_CONF_ZEXOS"
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true; rm -f "$MAKEPKG_CONF_ZEXOS"' EXIT

zexos_makepkg() {
    makepkg --config "$MAKEPKG_CONF_ZEXOS" "$@"
}

# Build on the disk, not in /tmp. Arch keeps /tmp in RAM (half of it), and
# linking noctalia needs more than that on a smaller machine: on a 6 GB VM
# it failed with "No space left on device". Each build folder is deleted
# when it's done.
ZEXOS_BUILD_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/zexos/build"
mkdir -p "$ZEXOS_BUILD_ROOT"
zexos_build_dir() {
    mktemp -d -p "$ZEXOS_BUILD_ROOT"
}

# Ready-made packages (ZEXOS_PACKAGES=prebuilt, picked in install.sh).
# Normally they come from ZeXOS's package repo (see "2. INSTALL EVERYTHING").
# If that isn't reachable, install_prebuilt <name> [<package it replaces>]
# tries, in order:
#   1. the AUR package <name>-bin, if you have yay or paru and it's there
#   2. the file on ZeXOS's GitHub release "prebuilt", checked against the
#      checksum in packaging/prebuilt.list
# and returns 1 if neither worked, so it's built here instead.
# The list is made by scripts/make-prebuilt.sh.
ZEXOS_PACKAGES="${ZEXOS_PACKAGES:-source}"
# --noconfirm answers "no" when a package wants to replace another, so the
# old one is removed by hand, only once the new one is in hand.
drop_replaced() {
    [ -n "$1" ] && [ "$(pacman -Qq "$1" 2>/dev/null)" = "$1" ] || return 0
    sudo pacman -Rdd --noconfirm "$1"
}
PREBUILT_LIST="$REPO_ROOT/packaging/prebuilt.list"
PREBUILT_URL="https://github.com/zefuros1991/ZeXOS/releases/download/prebuilt"

install_prebuilt() {
    local pkg=$1 old=${2:-} want name ver file sum extra helper dl
    [ "$ZEXOS_PACKAGES" = prebuilt ] || return 1
    want="$(. "$REPO_ROOT/packaging/$pkg/PKGBUILD"; echo "$pkgver-$pkgrel")"
    read -r name ver file sum extra < <(grep "^$pkg " "$PREBUILT_LIST" 2>/dev/null) || true
    if [ "$ver" != "$want" ]; then
        echo -e "${CYAN}  No ready-made $pkg $want yet, building it here${RESET}"
        return 1
    fi
    # qt6ct-kde only works with the Qt it was built against.
    if [ "${extra#qt=}" != "$extra" ]; then
        local qt; qt="$(pacman -Q qt6-base 2>/dev/null | awk '{print $2}')"
        if [ "$qt" != "${extra#qt=}" ]; then
            echo -e "${CYAN}  Ready-made $pkg is for Qt ${extra#qt=}, you have Qt $qt -- building it here${RESET}"
            return 1
        fi
    fi

    for helper in yay paru; do
        command -v "$helper" >/dev/null || continue
        if "$helper" -Si --aur "$pkg-bin" &>/dev/null && drop_replaced "$old" &&
           "$helper" -S --needed --noconfirm "$pkg-bin"; then
            echo -e "${GREEN}✔ $pkg $want installed (ready-made, from the AUR)${RESET}"
            return 0
        fi
        break
    done

    dl="$(zexos_build_dir)"
    if curl -fsSL --retry 3 -o "$dl/$file" "$PREBUILT_URL/$file" &&
       echo "$sum  $dl/$file" | sha256sum -c --quiet - &&
       drop_replaced "$old" &&
       sudo pacman -U --noconfirm --needed "$dl/$file"; then
        rm -rf "$dl"
        echo -e "${GREEN}✔ $pkg $want installed (ready-made, from GitHub)${RESET}"
        return 0
    fi
    rm -rf "$dl"
    echo -e "${YELLOW}⚠ Couldn't get the ready-made $pkg, building it here instead${RESET}"
    return 1
}

# =========================================================
# 1. THE LIST OF PACKAGES
# =========================================================
# Nothing is installed in this part. install_pacman and install_local only
# add to a list; everything on it is installed together further down
# ("2. INSTALL EVERYTHING"), in one pacman run. One run per package made
# pacman re-read its package lists, work out the dependencies and run its
# after-install steps ~60 times over, which was most of the install time.

GROUP_LABELS=()   # "Desktop Core", ...
GROUP_PKGS=()     # "niri kitty ...", one string per group
LOCAL_LABELS=()   # ZeXOS's own packages (packaging/<name>)
LOCAL_DIRS=()

# install_pacman <label> <package>...   packages from the distro's repos
install_pacman() {
    local label=$1
    shift
    GROUP_LABELS+=("$label")
    GROUP_PKGS+=("$*")
}

# install_local <label> <name>   one of ZeXOS's own, from packaging/<name>
# (the folder name is also the package name)
install_local() {
    LOCAL_LABELS+=("$1")
    LOCAL_DIRS+=("$2")
}

# The package each of ours replaces. --noconfirm answers "no" when a
# package wants to replace another, so the old one is removed by hand first.
declare -A REPLACES=(
    [noctalia-zexos]=noctalia
    [pixie-sddm-zexos]=pixie-sddm-git
    [bibata-cursor-zexos]=bibata-cursor-theme
    [qt6ct-kde]=qt6ct
)

# Is <package> in the distro's own repos? ZeXOS's repo (below) doesn't count.
# LC_ALL=C: pacman's labels are translated, "Repository" may be in Greek.
in_distro_repos() {
    LC_ALL=C pacman -Si "$1" 2>/dev/null | awk '/^Repository/ {print $3}' | grep -qvx zexos
}

# Which compositors and shells to install (picked in install.sh, or on the
# installer ISO). All of them when packages.sh runs on its own.
ZEXOS_COMPOSITORS="${ZEXOS_COMPOSITORS:-niri hyprland mango}"
ZEXOS_SHELLS="${ZEXOS_SHELLS:-noctalia dms}"
want_compositor() { case " $ZEXOS_COMPOSITORS " in *" $1 "*) return 0 ;; esac; return 1; }
want_shell() { case " $ZEXOS_SHELLS " in *" $1 "*) return 0 ;; esac; return 1; }
echo -e "${CYAN}Compositors: $ZEXOS_COMPOSITORS   Shells: $ZEXOS_SHELLS${RESET}"

# -----------------------------
# DESKTOP CORE
# -----------------------------
# The compositor, launcher and terminal ZeXOS is built around. CachyOS's
# niri profile already ships most of these; --needed makes this a no-op
# there and fills the gaps on plain Arch.
CORE_PACMAN=(
    fuzzel
    kitty
    neovim
    adw-gtk-theme
    fastfetch
    imagemagick
    ttf-jetbrains-mono-nerd
    # The shell names in the Mod+Shift+D menu.
    ttf-nunito
    # zexos-border reads the wallpaper's colours with it.
    python-pillow
)

# niri runs X11 apps through xwayland-satellite (Mango and Hyprland have
# their own Xwayland).
want_compositor niri && CORE_PACMAN+=(niri xwayland-satellite)

install_pacman "Desktop Core" "${CORE_PACMAN[@]}"

# -----------------------------
# DESKTOP BASICS
# -----------------------------
# What CachyOS's niri profile brings along and a KDE, GNOME or bare install
# may not have: portals (screen sharing, file dialogs), a password keyring,
# the clipboard tool, fonts, and the sound, network, Bluetooth and power
# services the bar talks to. KDE and GNOME installs already have most of
# these, so --needed skips them there. If one clashes with something you
# already use (say PulseAudio instead of PipeWire), pacman says no and your
# setup is kept; the bar just shows less for that one thing.
BASICS_PACMAN=(
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    gnome-keyring
    wl-clipboard
    noto-fonts
    noto-fonts-emoji
    xdg-user-dirs
    pipewire
    pipewire-pulse
    wireplumber
    networkmanager
    bluez
    bluez-utils
    power-profiles-daemon
    upower
    brightnessctl
    # checkupdates, which the bar's update counter needs. EndeavourOS and
    # CachyOS ship it; a plain Arch install does not.
    pacman-contrib
)

install_pacman "Desktop Basics" "${BASICS_PACMAN[@]}"

# -----------------------------
# MEDIA BASICS
# -----------------------------
MEDIA_PACMAN=(
    vlc
    ffmpeg
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
)

install_pacman "Media Basics" "${MEDIA_PACMAN[@]}"

# -----------------------------
# SYSTEM
# -----------------------------
# xorg-xhost and polkit-kde-agent make privileged GUI apps (gparted and
# friends) actually work out of the box under niri + Xwayland:
#   - polkit-kde-agent is the auth agent niri's autostart.kdl spawns
#     (`/usr/lib/polkit-kde-authentication-agent-1`) -- without it pkexec
#     fails immediately with "No authentication agent found".
#   - xorg-xhost is a soft dependency of gparted's own launcher script,
#     which grants the pkexec'd root process X access via `xhost` before
#     handing off. Without it, auth succeeds but the root GUI process can't
#     open the display ("cannot open display" Gtk-WARNING).
SYSTEM_PACMAN=(
    btop
    gparted
    xorg-xhost
    polkit-kde-agent
)

install_pacman "System Tools" "${SYSTEM_PACMAN[@]}"

# -----------------------------
# FILE MANAGER (DOLPHIN)
# -----------------------------
# Nautilus was the niri default but couldn't do pinned/mounted-partition
# sidebar entries or a working "set as default app" flow. Switched to
# Dolphin (2026-09-03) -- kio-extras adds network/archive/etc backends to
# its sidebar, kde-cli-tools brings kioclient/kwrite helpers it shells out
# to. Confirmed working under niri. Papirus is the icon theme; its folders
# are recoloured to follow the wallpaper (see make-papirus-zexos.py).
FILE_MANAGER_PACMAN=(
    dolphin
    kio-extras
    kde-cli-tools
    gwenview
    papirus-icon-theme
)

install_pacman "File Manager (Dolphin)" "${FILE_MANAGER_PACMAN[@]}"

# -----------------------------
# NOCTALIA EXTRAS
# -----------------------------
# udiskie/udisks2/xdg-utils: the aristides/udiskie plugin (USB widget in the
# bar) shells out to all three. layer-shell-qt + build tools: roller, below.
NOCTALIA_PACMAN=(
    udiskie
    udisks2
    xdg-utils
    layer-shell-qt
    cmake
)

install_pacman "Noctalia Extras" "${NOCTALIA_PACMAN[@]}"

# -----------------------------
# ROLLER (wallpaper picker, Mod+W)
# -----------------------------
# Not in the repos -- built from packaging/roller (upstream pinned to a known
# commit + our wheel/size patch). Config and the waypaper->noctalia shim live
# in stow/roller. Reinstalled only when the installed version differs from ours.
install_local "Wallpaper picker (Roller)" roller

# -----------------------------
# NOCTALIA (patched: bar islands attached to the top edge, bigger launcher)
# -----------------------------
# The stock package comes with CachyOS's niri profile. We swap it for
# packaging/noctalia-zexos: the official Arch PKGBUILD plus a small patch
# that adds `attached = true` to bar capsule groups (square top corners,
# round bottom ones) and `[accessibility] launcher_scale` (launcher-only size). Separate package name, so repo updates can't undo it.
want_shell noctalia && install_local "Noctalia (ZeXOS patch)" noctalia-zexos

# -----------------------------
# DANKMATERIALSHELL (the second desktop shell)
# -----------------------------
# Installed next to Noctalia; Noctalia stays the default. Mod+Shift+D
# (`zshell menu`) switches between them, per user. dms-shell-niri pulls in
# the niri support, matugen makes the colours from the wallpaper.
# Since dms-shell 1.6.2-2 (Arch, 2026-10-03) the niri and Hyprland support
# is part of dms-shell itself and dms-shell-niri/-hyprland are gone. Older
# repos (CachyOS may lag a few days) still split them, and there dms-shell
# needs "a compositor" package; --noconfirm would pick the first one offered,
# so dms-shell-niri goes first when the repo still has it.
# With only Mango picked, dms-shell-niri is still the one to take there.
if want_shell dms; then
    DMS_PACMAN=()
    if want_compositor niri || ! want_compositor hyprland; then
        pacman -Si dms-shell-niri &>/dev/null && DMS_PACMAN+=(dms-shell-niri)
    fi
    DMS_PACMAN+=(
        dms-shell
        matugen
    )

    install_pacman "DankMaterialShell" "${DMS_PACMAN[@]}"
fi

# -----------------------------
# MANGO (a second compositor, picked at the login screen)
# -----------------------------
# Mango (mangowm) scrolls windows sideways like niri. It ships its own
# login-screen entry and portal settings. xdg-desktop-portal-wlr does screen
# sharing; grim, slurp and wl-clipboard do screenshots (zexos-screenshot).
# All in the Arch/CachyOS repos.
MANGO_PACMAN=(
    mangowm
    xdg-desktop-portal-wlr
    grim
    slurp
    wl-clipboard
)

want_compositor mango && install_pacman "Mango" "${MANGO_PACMAN[@]}"

# -----------------------------
# HYPRLAND (a third compositor, picked at the login screen)
# -----------------------------
# Hyprland tiles windows: each new one takes half of the one you're in.
# It ships its own login-screen entry. xdg-desktop-portal-hyprland does
# screen sharing; grim, slurp and wl-clipboard do screenshots, like Mango.
# dms-shell-hyprland is DMS's Hyprland support on repos that still split it
# out (see DankMaterialShell above). All in the Arch/CachyOS repos.
HYPR_PACMAN=(
    hyprland
    xdg-desktop-portal-hyprland
    grim
    slurp
    wl-clipboard
)
want_shell dms && pacman -Si dms-shell-hyprland &>/dev/null && HYPR_PACMAN+=(dms-shell-hyprland)

want_compositor hyprland && install_pacman "Hyprland" "${HYPR_PACMAN[@]}"

# -----------------------------
# ZEXOS'S OWN PACKAGES
# -----------------------------
# A few things aren't in the CachyOS/Arch repos. Each has a small recipe in
# packaging/ that downloads it straight from its author and checks it
# against a fixed checksum. makepkg turns it into a normal package, so
# pacman can update or remove it like any other. With the fast install
# (ZEXOS_PACKAGES=prebuilt) they come ready-made from ZeXOS's own package
# repo instead; see "2. INSTALL EVERYTHING".

# -----------------------------
# DISTRO-SPECIFIC STEPS
# -----------------------------
# The few things that differ between CachyOS and other Arch-based systems
# (the app store) live in scripts/distro/<name>.sh.
# lib-distro.sh works out which one to use; see the notes at its top.
. "$REPO_ROOT/scripts/lib-distro.sh"
zexos_detect_distro
if [ -r "$REPO_ROOT/scripts/distro/$ZEXOS_DISTRO.sh" ]; then
    echo -e "\n${YELLOW}[DISTRO] Steps for ${ZEXOS_DISTRO_NAME} (${ZEXOS_DISTRO})${RESET}"
    . "$REPO_ROOT/scripts/distro/$ZEXOS_DISTRO.sh"
else
    echo -e "${RED}✖ No distro steps for ${ZEXOS_DISTRO_NAME} (${ZEXOS_DISTRO_WHY:-$ZEXOS_DISTRO}) -- skipping them${RESET}"
fi

# Mouse pointer (Bibata Modern Ice). Replaces the old AUR package if present.
install_local "Mouse pointer (Bibata)" bibata-cursor-zexos

# -----------------------------
# VIDEO WALLPAPER (mpvpaper)
# -----------------------------
# Plays the animated zexos-topo-energy wallpaper, through Noctalia's
# "Video Wallpaper" plugin. CachyOS has mpvpaper in its repos; plain Arch
# and EndeavourOS don't, so there it is built from packaging/mpvpaper.
# socat is optional: the plugin uses it to keep a video slideshow in step.
install_pacman "Video Wallpaper" mpv socat
if in_distro_repos mpvpaper; then
    install_pacman "Video Wallpaper (mpvpaper)" mpvpaper
else
    install_local "Video Wallpaper (mpvpaper)" mpvpaper
fi

# -----------------------------
# LOGIN MANAGER: SDDM PIXIE
# -----------------------------
# The theme's own package pulls in sddm and the Qt parts it needs.
# It replaces the old AUR version (pixie-sddm-git) if that's installed.
install_local "Login screen theme (Pixie)" pixie-sddm-zexos

# -----------------------------
# QT6CT-KDE (dark theme for Dolphin, Gwenview)
# -----------------------------
# Plain qt6ct can't pass the colour scheme to KDE apps outside Plasma, so
# they stay bright white. This patched build can (see packaging/qt6ct-kde).
# It replaces plain qt6ct if something installed that.
install_local "Qt settings for KDE apps (qt6ct-kde)" qt6ct-kde

# =========================================================
# 2. INSTALL EVERYTHING
# =========================================================

# sudo pacman <args> with a spinner; returns pacman's exit code.
run_pacman() {
    local msg=$1 pid
    shift
    sudo pacman "$@" &
    pid=$!
    spinner "$pid" "$msg"
    wait "$pid"
}

# Prints the packages from the arguments that aren't installed yet.
# (pacman -T counts a package that stands in for another, like -Qi does.)
not_installed() {
    [ "$#" -gt 0 ] || return 0
    pacman -T "$@" || true
}

# The version packaging/<name>/PKGBUILD makes, and the installed one.
want_version() { (. "$REPO_ROOT/packaging/$1/PKGBUILD"; echo "$pkgver-$pkgrel"); }
have_version() { pacman -Q "$1" 2>/dev/null | awk '{print $2}'; }

# Removes the package <name> replaces, if it's installed (see REPLACES).
DROPPED=()
drop_old() {
    local old=${REPLACES[$1]:-}
    if [ -n "$old" ] && [ "$(pacman -Qq "$old" 2>/dev/null)" = "$old" ]; then
        sudo pacman -Rdd --noconfirm "$old"
        DROPPED+=("$old")
    fi
}

# If a batch fails (say one package clashes with something you use, like
# PulseAudio instead of PipeWire), install one at a time: the rest still
# go in, and the log names the one that didn't.
one_by_one() {
    local pkg
    for pkg in "$@"; do
        pacman -T "${pkg#zexos/}" >/dev/null && continue
        run_pacman "Installing $pkg" -S --needed --noconfirm "$pkg" ||
            echo -e "${RED}✖ Failed to install $pkg${RESET}"
    done
}

# -----------------------------
# ZEXOS'S PACKAGE REPO (fast install only)
# -----------------------------
# The ready-made packages (made by scripts/make-prebuilt.sh) sit on the
# GitHub release "prebuilt", next to a package list pacman understands
# (zexos.db). With that added to /etc/pacman.conf, pacman fetches them in
# the same run as everything else, and updates them with the rest of the
# system later (pacman -Syu), like any repo.
# Trust: zexos.db must match the checksum in packaging/prebuilt.list, and
# zexos.db holds each package's checksum, which pacman checks in turn. If
# anything's off, the repo is taken out again and install_prebuilt (above)
# fetches the files one by one instead.
remove_zexos_repo() {
    grep -q '^\[zexos\]' /etc/pacman.conf || return 0
    sudo sed -i '/^# ZeXOS ready-made packages/d; /^\[zexos\]/,/^$/d' /etc/pacman.conf
    sudo rm -f /var/lib/pacman/sync/zexos.db /var/lib/pacman/sync/zexos.files
}

if [ "$ZEXOS_PACKAGES" = prebuilt ]; then
    if ! grep -q '^\[zexos\]' /etc/pacman.conf; then
        printf '\n# ZeXOS ready-made packages (added by ZeXOS install.sh)\n[zexos]\nSigLevel = Optional TrustAll\nServer = %s\n' \
            "$PREBUILT_URL" | sudo tee -a /etc/pacman.conf >/dev/null
    fi
else
    remove_zexos_repo
fi

echo -e "\n${YELLOW}[PACMAN] Package lists${RESET}"
if ! run_pacman "Refreshing package lists" -Sy --noconfirm; then
    if grep -q '^\[zexos\]' /etc/pacman.conf; then
        echo -e "${YELLOW}⚠ Couldn't reach ZeXOS's package repo, using the slower way${RESET}"
        remove_zexos_repo
        run_pacman "Refreshing package lists" -Sy --noconfirm || true
    fi
fi

ZEXOS_REPO_OK=0
if grep -q '^\[zexos\]' /etc/pacman.conf; then
    want_db="$(awk '$1 == "zexos.db" {print $4}' "$PREBUILT_LIST" 2>/dev/null)"
    have_db="$(sha256sum /var/lib/pacman/sync/zexos.db 2>/dev/null | cut -d' ' -f1)"
    if [ -n "$want_db" ] && [ "$have_db" = "$want_db" ]; then
        ZEXOS_REPO_OK=1
        echo -e "${GREEN}✔ ZeXOS's package repo is ready${RESET}"
    else
        # Usually just a newer ZeXOS on GitHub than this copy; install.sh
        # from the newer one puts the repo back.
        echo -e "${YELLOW}⚠ ZeXOS's package repo doesn't match this copy of ZeXOS, using the slower way${RESET}"
        remove_zexos_repo
    fi
fi

# Is the ready-made <name> in prebuilt.list the version we want, and (for
# qt6ct-kde) made for the Qt this install ends up with?
listed_ok() {
    local pkg=$1 name ver file sum extra qt
    read -r name ver file sum extra < <(grep "^$pkg " "$PREBUILT_LIST" 2>/dev/null) || return 1
    [ "$ver" = "$(want_version "$pkg")" ] || return 1
    if [ "${extra#qt=}" != "$extra" ]; then
        qt="$(LC_ALL=C pacman -Si qt6-base 2>/dev/null | awk '/^Version/ {print $3; exit}')"
        [ "$qt" = "${extra#qt=}" ] || return 1
    fi
}

# -----------------------------
# WHAT GOES WHERE
# -----------------------------
REPO_TARGETS=()   # zexos/<name>: ready-made, joins the big pacman run
FALLBACK=()       # ready-made, but the repo isn't there: install_prebuilt
BUILDS=()         # built on this computer
for dir in "${LOCAL_DIRS[@]}"; do
    [ "$(have_version "$dir")" = "$(want_version "$dir")" ] && continue
    if [ "$ZEXOS_PACKAGES" != prebuilt ]; then
        BUILDS+=("$dir")
    elif [ "$ZEXOS_REPO_OK" = 1 ] && listed_ok "$dir"; then
        REPO_TARGETS+=("zexos/$dir")
    elif [ "$ZEXOS_REPO_OK" = 1 ]; then
        echo -e "${CYAN}  No ready-made $dir $(want_version "$dir") for this system, building it here${RESET}"
        BUILDS+=("$dir")
    else
        FALLBACK+=("$dir")
    fi
done

ALL_REPO=()
for group in "${GROUP_PKGS[@]}"; do
    read -r -a pkgs <<< "$group"
    ALL_REPO+=("${pkgs[@]}")
done
mapfile -t NEED < <(not_installed "${ALL_REPO[@]}" | sort -u)

# Everything a build needs. makepkg would install these itself, but then
# it can't run while pacman installs the rest.
mapfile -t BUILD_DEPS < <(
    for dir in "${BUILDS[@]}"; do
        (. "$REPO_ROOT/packaging/$dir/PKGBUILD"; printf '%s\n' "${depends[@]}" "${makedepends[@]}")
    done | sed 's/[<>=].*//' | sort -u | xargs -r pacman -T || true
)

# Make room for ours: remove what they replace (and put it back at the
# end if ours didn't make it, see "Anything missing?").
for target in "${REPO_TARGETS[@]}"; do
    drop_old "${target#zexos/}"
done

# Builds run next to pacman: noctalia-zexos (the long one) on its own,
# the rest one after another. Each writes a log to ~/.cache/zexos/build/.
BUILT_DIR="$(zexos_build_dir)"
build_one() {
    local dir=$1 b rc=0
    shift
    b="$(zexos_build_dir)"
    cp "$REPO_ROOT/packaging/$dir"/* "$b/"
    if (cd "$b" && zexos_makepkg --noconfirm "$@") >"$ZEXOS_BUILD_ROOT/$dir.log" 2>&1; then
        mv "$b"/*.pkg.tar.zst "$BUILT_DIR/"
    else
        rc=1
    fi
    rm -rf "$b"
    return "$rc"
}
build_lane() {
    local dir
    for dir in "$@"; do
        build_one "$dir" || echo "$dir" >> "$BUILT_DIR/failed"
    done
}

# -----------------------------
# THE BIG PACMAN RUN
# -----------------------------
# The system upgrade and every missing package in one go. pacman downloads
# several files at once (ParallelDownloads in /etc/pacman.conf). When
# something has to be built, it goes in two steps: first the upgrade plus
# what the builds need, then the builds start while the rest installs.
if [ "${#BUILDS[@]}" -gt 0 ]; then
    FIRST=("${BUILD_DEPS[@]}")
    SECOND=("${NEED[@]}" "${REPO_TARGETS[@]}")
else
    FIRST=("${NEED[@]}" "${REPO_TARGETS[@]}")
    SECOND=()
fi

echo -e "\n${YELLOW}[PACMAN] Updating the system and installing ${#FIRST[@]} packages${RESET}"
if run_pacman "Updating and installing" -Su --needed --noconfirm "${FIRST[@]}"; then
    echo -e "${GREEN}✔ Done${RESET}"
else
    echo -e "${YELLOW}⚠ That didn't go through in one go, trying one package at a time${RESET}"
    run_pacman "Updating system" -Su --noconfirm ||
        echo -e "${RED}✖ System upgrade failed — continuing anyway, but package installs below may also fail${RESET}"
    one_by_one "${FIRST[@]}"
fi

lanes=()
if [ "${#BUILDS[@]}" -gt 0 ]; then
    heavy=() light=()
    for dir in "${BUILDS[@]}"; do
        if [ "$dir" = noctalia-zexos ]; then heavy+=("$dir"); else light+=("$dir"); fi
    done
    echo -e "\n${YELLOW}[BUILD] Building ${BUILDS[*]} (logs in $ZEXOS_BUILD_ROOT)${RESET}"
    [ "${#heavy[@]}" -gt 0 ] && { build_lane "${heavy[@]}" & lanes+=($!); }
    [ "${#light[@]}" -gt 0 ] && { build_lane "${light[@]}" & lanes+=($!); }
fi

if [ "${#SECOND[@]}" -gt 0 ]; then
    echo -e "\n${YELLOW}[PACMAN] Installing ${#SECOND[@]} packages${RESET}"
    run_pacman "Installing" -S --needed --noconfirm "${SECOND[@]}" || {
        echo -e "${YELLOW}⚠ That didn't go through in one go, trying one package at a time${RESET}"
        one_by_one "${SECOND[@]}"
    }
fi

# Ready-made the old way (the repo wasn't there): the AUR or a GitHub
# download, one by one. Whatever fails is built below.
for dir in "${FALLBACK[@]}"; do
    install_prebuilt "$dir" "${REPLACES[$dir]:-}" || echo "$dir" >> "$BUILT_DIR/failed"
done

for pid in "${lanes[@]}"; do
    spinner "$pid" "Building"
    wait "$pid" || true
done

# Builds that failed get one more go, one at a time, now that pacman is
# free: -s lets makepkg install anything still missing.
if [ -s "$BUILT_DIR/failed" ]; then
    while read -r dir; do
        echo -e "${CYAN}Building $dir${RESET}"
        build_one "$dir" -s ||
            echo -e "${RED}✖ $dir build failed, see $ZEXOS_BUILD_ROOT/$dir.log${RESET}"
    done < "$BUILT_DIR/failed"
fi

# Install everything that was built, in one go.
shopt -s nullglob
built=("$BUILT_DIR"/*.pkg.tar.zst)
shopt -u nullglob
if [ "${#built[@]}" -gt 0 ]; then
    for file in "${built[@]}"; do
        drop_old "$(pacman -Qpq "$file")"
    done
    echo -e "\n${YELLOW}[PACMAN] Installing ${#built[@]} packages built here${RESET}"
    run_pacman "Installing" -U --needed --noconfirm "${built[@]}" || {
        for file in "${built[@]}"; do
            run_pacman "Installing ${file##*/}" -U --needed --noconfirm "$file" ||
                echo -e "${RED}✖ Failed to install ${file##*/}${RESET}"
        done
    }
fi
rm -rf "$BUILT_DIR"

# -----------------------------
# ANYTHING MISSING?
# -----------------------------
# Put back what was removed to make room, if ours didn't make it (stock
# noctalia beats no bar at all).
for old in "${DROPPED[@]}"; do
    for new in "${!REPLACES[@]}"; do
        [ "${REPLACES[$new]}" = "$old" ] || continue
        if ! pacman -Q "$new" &>/dev/null && in_distro_repos "$old"; then
            echo -e "${YELLOW}⚠ $new didn't install, putting $old back${RESET}"
            run_pacman "Installing $old" -S --needed --noconfirm "$old" || true
        fi
    done
done

echo -e "\n${YELLOW}[RESULT]${RESET}"
for i in "${!GROUP_LABELS[@]}"; do
    read -r -a pkgs <<< "${GROUP_PKGS[$i]}"
    missing="$(not_installed "${pkgs[@]}" | tr '\n' ' ')"
    if [ -z "$missing" ]; then
        echo -e "${GREEN}✔ ${GROUP_LABELS[$i]}${RESET}"
    else
        echo -e "${RED}✖ ${GROUP_LABELS[$i]}: missing ${missing}${RESET}"
    fi
done
for i in "${!LOCAL_DIRS[@]}"; do
    dir=${LOCAL_DIRS[$i]}
    if [ "$(have_version "$dir")" = "$(want_version "$dir")" ]; then
        echo -e "${GREEN}✔ ${LOCAL_LABELS[$i]} ($dir $(want_version "$dir"))${RESET}"
    else
        echo -e "${RED}✖ ${LOCAL_LABELS[$i]}: $dir $(want_version "$dir") not installed${RESET}"
    fi
done

echo -e "\n${YELLOW}[SDDM] Configuration${RESET}"

if [ -d /usr/share/sddm/themes/pixie ]; then

    sudo mkdir -p /etc/sddm.conf.d

    sudo tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=pixie
EOF

    echo -e "${GREEN}✔ Pixie theme configured${RESET}"

    # The login screen runs on X11, where a touchpad tap is not a click
    # unless you turn it on. Only added if you have no touchpad file of
    # your own. https://wiki.archlinux.org/title/Libinput#Via_Xorg_configuration_file
    tap=/etc/X11/xorg.conf.d/30-touchpad.conf
    if [ ! -e "$tap" ]; then
        sudo mkdir -p /etc/X11/xorg.conf.d
        sudo tee "$tap" >/dev/null <<EOF
# ZeXOS: tap the touchpad to click on the login screen (and any X11 session).
Section "InputClass"
    Identifier "touchpad"
    MatchIsTouchpad "on"
    MatchDriver "libinput"
    Option "Tapping" "on"
EndSection
EOF
        echo -e "${GREEN}✔ Login screen: touchpad tap clicks${RESET}"
    fi

else
    echo -e "${RED}✖ Pixie theme directory not found${RESET}"
fi

# If the symlink doesn't exist at all (e.g. a genuinely fresh install with
# no display manager configured yet), `readlink` fails and the old
# `|| echo "none"` fallback never actually fired here — basename of an
# empty string is itself an empty string, not "none", which then made
# `sudo systemctl disable ""` run below and abort the whole script under
# `set -e`. Checking for the symlink explicitly first avoids that.
if [ -L /etc/systemd/system/display-manager.service ]; then
    CURRENT_DM=$(basename "$(readlink /etc/systemd/system/display-manager.service)" .service)
else
    CURRENT_DM="none"
fi

if [ "$CURRENT_DM" != "sddm" ]; then

    # Another login screen may be in use (GDM on GNOME, Plasma Login on
    # newer KDE, ...). ZeXOS replaces it with SDDM + Pixie, but only once
    # everything the new one needs is really there: SDDM itself, the Pixie
    # theme, and the setting that picks it. Otherwise switching would swap a
    # working login screen for a broken one, so keep the old one instead.
    # (The login wallpaper sync is set up in finaltouches.sh.)
    pixie_ready=1
    for need in /usr/bin/sddm \
                /usr/share/sddm/themes/pixie/Main.qml \
                /usr/share/sddm/themes/pixie/metadata.desktop; do
        [ -e "$need" ] || { pixie_ready=0; echo -e "${RED}✖ Missing $need${RESET}"; }
    done
    grep -qx 'Current=pixie' /etc/sddm.conf.d/theme.conf 2>/dev/null || pixie_ready=0

    if [ "$pixie_ready" = 1 ]; then
        echo -e "${CYAN}Switching display manager from ${CURRENT_DM} to sddm${RESET}"
        [ "$CURRENT_DM" != "none" ] && sudo systemctl disable "$CURRENT_DM"
        sudo systemctl enable sddm
        echo -e "${GREEN}✔ SDDM with Pixie enabled${RESET}"
    else
        echo -e "${RED}✖ SDDM or the Pixie theme isn't ready, keeping ${CURRENT_DM} as the login screen${RESET}"
        echo -e "${CYAN}  Pick \"niri\" in its session list to start ZeXOS, and run install.sh again to retry${RESET}"
    fi

else
    echo -e "${GREEN}✔ SDDM already active${RESET}"
fi


# Qt updates can break qt6ct-kde, and pacman won't rebuild it for us (it
# isn't in any repo). This pacman hook rebuilds it in the background after
# every Qt update. See system/qt6ct-rebuild/.
if [ "$(pacman -Qq qt6ct-kde 2>/dev/null)" = "qt6ct-kde" ]; then
    rebuild_src="$REPO_ROOT/system/qt6ct-rebuild"
    sudo install -Dm755 "$rebuild_src/zexos-qt6ct-rebuild" /usr/local/lib/zexos/zexos-qt6ct-rebuild
    sudo install -Dm644 "$rebuild_src/zexos-qt6ct-rebuild.service" /etc/systemd/system/zexos-qt6ct-rebuild.service
    sudo install -Dm644 "$rebuild_src/zexos-qt6ct-rebuild.hook" /etc/pacman.d/hooks/zexos-qt6ct-rebuild.hook
    sudo install -d /etc/zexos
    printf 'ZEXOS_USER=%q\nZEXOS_REPO=%q\n' "$USER" "$REPO_ROOT" | sudo tee /etc/zexos/qt6ct-rebuild.conf >/dev/null
    sudo systemctl daemon-reload
    echo -e "${GREEN}✔ qt6ct-kde will rebuild itself after Qt updates${RESET}"
fi

# The desktop helpers (zshell and friends) live in ~/.local/bin, and the
# compositors call them by name. Plain Arch doesn't put that folder on PATH,
# which left the desktop black. See system/profile.d/.
sudo install -Dm644 "$REPO_ROOT/system/profile.d/zexos-local-bin.sh" /etc/profile.d/zexos-local-bin.sh
echo -e "${GREEN}✔ ~/.local/bin is on PATH for every login${RESET}"

# Two-GPU laptops: make Mango draw on the GPU the built-in screen is wired
# to, or that screen stays a solid colour. See system/profile.d/.
sudo install -Dm644 "$REPO_ROOT/system/profile.d/zexos-gpu-order.sh" /etc/profile.d/zexos-gpu-order.sh
echo -e "${GREEN}✔ Mango uses the right GPU on two-GPU laptops${RESET}"

# =========================================================
# 3. FLATPAK / FLATHUB
# =========================================================

echo -e "\n${YELLOW}[FLATPAK] Setup${RESET}"

if ! command -v flatpak >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm flatpak &
    flatpak_install_pid=$!
    spinner "$flatpak_install_pid" "Installing Flatpak"

    if wait "$flatpak_install_pid"; then
        echo -e "${GREEN}✔ Flatpak installed${RESET}"
    else
        echo -e "${RED}✖ Failed to install Flatpak — remote/app steps below will also fail${RESET}"
    fi
fi

if ! flatpak remotes | grep -q flathub; then
    echo -e "${CYAN}Adding Flathub repository${RESET}"
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

FLATPAK_APPS=(
    com.github.tchx84.Flatseal
)

echo -e "\n${YELLOW}[FLATPAK] Applications${RESET}"

for app in "${FLATPAK_APPS[@]}"; do
    if flatpak list | grep -qi "$app"; then
        echo -e "${GREEN}✔ $app already installed${RESET}"
    else
        sudo flatpak install -y --system flathub "$app" || echo -e "${RED}✖ Failed to install $app${RESET}"
    fi
done

# -----------------------------
# DONE
# -----------------------------
echo -e "\n${GREEN}${BOLD}✔ PACKAGE INSTALL COMPLETE${RESET}"
echo -e "${BLUE}Log saved to: $LOGFILE${RESET}"
