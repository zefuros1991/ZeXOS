#!/usr/bin/env bash
set -e

DOTFILES="$HOME/.dotfiles"
STOW_DIR="$DOTFILES/stow"
BACKUP_DIR="$DOTFILES/backup/stow-$(date +%Y%m%d-%H%M%S)"
LOGFILE="$DOTFILES/stow.log"

# -----------------------------
# XDG environment (defensive)
# -----------------------------
# Normally already exported by install.sh before this script runs, but set
# it up here too in case stow.sh is ever run on its own — this also makes
# sure XDG_* target directories exist before any package gets folded into
# them. Idempotent — see scripts/lib-xdg.sh.
. "$DOTFILES/scripts/lib-xdg.sh"
zexos_setup_xdg_env

# NOTE: BACKUP_DIR is deliberately NOT created here. The inner backup loop
# below already does `mkdir -p "$BACKUP_DIR/..."` for each file it actually
# backs up, which is enough to create BACKUP_DIR itself as a side effect.
# Creating it unconditionally up front meant every single run of this
# script left behind a new empty timestamped folder under backup/, even on
# a run where nothing needed backing up at all.
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
# Track outcomes so we can print an honest summary at the end instead of
# just always printing a checkmark (stow's own exit status used to be
# thrown away here — a package could fail to link and this script would
# still report success for it).
ALREADY_LINKED=()
DEPLOYED_CLEAN=()
DEPLOYED_WITH_BACKUP=()
FAILED_PACKAGES=()
ANY_BACKUP_MADE=0

for pkg in "$STOW_DIR"/*; do
    [ -d "$pkg" ] || continue

    package_name=$(basename "$pkg")

    echo -e "\n${YELLOW}==> Package: $package_name${RESET}"

    # -------------------------
    # CHECK IF PACKAGE ALREADY PROPERLY STOWED
    # -------------------------
    # NOTE: GNU stow's plain dry-run (-n) exits 0 whenever there would be
    # no CONFLICT, whether or not there's actually anything to link — it
    # never prints "no conflicts" as text, so the old
    # `grep -q "no conflicts"` check here never matched anything and this
    # fast path never fired (every package got needlessly re-stowed on
    # every run). Verbose dry-run (-v -n) does print one "LINK: ..." line
    # per pending change, so its absence (with a clean exit) is what
    # actually means "already fully linked, nothing to do".
    # Assignment-from-command-substitution as its own statement would trip
    # `set -e` the moment a package has real conflicts (dry-run exits 1) —
    # same gotcha as the `wait` below, same fix: make it the condition of
    # an `if` so a non-zero exit here doesn't kill the whole script.
    if dry_run_output=$(stow -v -d "$STOW_DIR" -t "$HOME" -n "$package_name" 2>&1); then
        dry_run_status=0
    else
        dry_run_status=$?
    fi

    if [ "$dry_run_status" -eq 0 ] && ! grep -qE '^(LINK|UNLINK):' <<< "$dry_run_output"; then
        echo -e "${GREEN}✔ Already correctly stowed: $package_name${RESET}"
        ALREADY_LINKED+=("$package_name")
        continue
    fi

    # -------------------------
    # BACKUP CONFLICTS ONLY
    # -------------------------
    backed_up_this_pkg=0
    while IFS= read -r file; do
        target="$HOME/${file#$pkg/}"

        if [ -e "$target" ] && [ ! -L "$target" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "${file#$pkg/}")"
            mv "$target" "$BACKUP_DIR/${file#$pkg/}"

            echo -e "${YELLOW}⚠ Backed up:${RESET} $target"
            backed_up_this_pkg=1
            ANY_BACKUP_MADE=1
        fi
    done < <(find "$pkg" -type f)

    # -------------------------
    # STOW PACKAGE
    # -------------------------
    stow -d "$STOW_DIR" -t "$HOME" "$package_name" &
    stow_pid=$!
    spinner "$stow_pid" "Stowing $package_name"

    # `wait` as an `if` condition so `set -e` doesn't kill the whole script
    # on a single package's failure — we want to keep going and report it.
    if wait "$stow_pid"; then
        stow_status=0
    else
        stow_status=$?
    fi

    if [ "$stow_status" -eq 0 ]; then
        echo -e "${GREEN}✔ Done: $package_name${RESET}"
        if [ "$backed_up_this_pkg" -eq 1 ]; then
            DEPLOYED_WITH_BACKUP+=("$package_name")
        else
            DEPLOYED_CLEAN+=("$package_name")
        fi
    else
        echo -e "${RED}✖ FAILED to stow: $package_name (exit code $stow_status — see $LOGFILE)${RESET}"
        FAILED_PACKAGES+=("$package_name")
    fi
done

# -----------------------------
# POST-STOW VERIFICATION SUMMARY
# -----------------------------
echo -e "\n${YELLOW}==> STOW SUMMARY${RESET}"

if [ "${#ALREADY_LINKED[@]}" -gt 0 ]; then
    echo -e "${GREEN}Already linked (no changes needed):${RESET} ${ALREADY_LINKED[*]}"
fi

if [ "${#DEPLOYED_CLEAN[@]}" -gt 0 ]; then
    echo -e "${GREEN}Newly deployed (no conflicts):${RESET} ${DEPLOYED_CLEAN[*]}"
fi

if [ "${#DEPLOYED_WITH_BACKUP[@]}" -gt 0 ]; then
    echo -e "${YELLOW}Deployed after backing up existing files:${RESET} ${DEPLOYED_WITH_BACKUP[*]}"
fi

if [ "${#FAILED_PACKAGES[@]}" -gt 0 ]; then
    echo -e "${RED}FAILED — these packages did NOT deploy, check $LOGFILE:${RESET} ${FAILED_PACKAGES[*]}"
fi

echo ""
if [ "${#FAILED_PACKAGES[@]}" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✔ STOW COMPLETE — all packages deployed${RESET}"
else
    echo -e "${RED}${BOLD}✖ STOW FINISHED WITH ${#FAILED_PACKAGES[@]} FAILED PACKAGE(S)${RESET}"
fi

if [ "$ANY_BACKUP_MADE" -eq 1 ]; then
    echo -e "${BLUE}Backup:${RESET} $BACKUP_DIR"
else
    echo -e "${BLUE}Backup:${RESET} none needed, no pre-existing files were in the way"
fi
echo -e "${BLUE}Log:${RESET} $LOGFILE"

# Exit non-zero if anything failed, so install.sh's `set -e` (and anyone
# scripting around this) can actually notice, instead of silently
# continuing to finaltouches.sh as if everything worked.
if [ "${#FAILED_PACKAGES[@]}" -gt 0 ]; then
    exit 1
fi

