#!/usr/bin/env bash
# ZeXOS shared XDG bootstrap helper.
#
# This file is meant to be SOURCED (". scripts/lib-xdg.sh"), not executed,
# by install.sh and by each stage script. Sourcing it does nothing by
# itself — it only defines the zexos_setup_xdg_env function below. Call
# that function to actually set things up.
#
# Why this exists: on a brand-new machine, the "real" XDG config
# (stow/system/.config/environment.d/10-xdg.conf) only takes effect on the
# NEXT login, because systemd's environment.d is read once at session
# start. That left a gap during the very first install: package installs,
# first-run apps, and even stow.sh itself were running with no XDG_* vars
# set at all, before the user ever logged out and back in. This function
# closes that gap for the CURRENT boot/run, without touching the real
# repo-managed file once it exists.
#
# Safe to call multiple times (idempotent) and safe to run standalone,
# before the repo's own environment.d file has been stowed.

zexos_setup_xdg_env() {
    # Respect anything already set (a prior call to this function earlier
    # in the same run, or a value the user's shell already exported).
    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_STATE_HOME:=$HOME/.local/state}"

    export XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME

    # Make sure the directories exist so the first package/app that wants
    # to write into them doesn't have to create its own parent dir first
    # (some tools fail silently instead of doing that).
    mkdir -p \
        "$XDG_CONFIG_HOME" \
        "$XDG_CACHE_HOME" \
        "$XDG_DATA_HOME" \
        "$XDG_STATE_HOME" \
        "$XDG_CONFIG_HOME/environment.d"

    local target="$XDG_CONFIG_HOME/environment.d/10-xdg.conf"
    local marker="# Written by ZeXOS scripts/lib-xdg.sh (interim, pre-stow)"

    # Already the real, repo-managed symlink from the "system" stow
    # package (this machine's normal steady state) — do not touch it.
    if [ -L "$target" ]; then
        return 0
    fi

    if [ -e "$target" ]; then
        # An interim file we wrote on an earlier/partial run of this same
        # installer — fine to leave as-is, scripts/stow.sh will back it up
        # and replace it with the real symlink automatically.
        if head -n1 "$target" 2>/dev/null | grep -qF "$marker"; then
            return 0
        fi
        # Some other real file already lives here (hand-edited, or from a
        # different tool). Never overwrite something we didn't create.
        return 0
    fi

    cat > "$target" << EOF
$marker
# Temporary copy written during install so this boot's login session and
# package installs see XDG paths immediately, instead of waiting for the
# next login. Once scripts/stow.sh runs, the "system" stow package
# replaces this file with the real, version-controlled one from the repo
# (stow.sh backs this file up first — nothing here is ever lost).
XDG_CONFIG_HOME=$XDG_CONFIG_HOME
XDG_CACHE_HOME=$XDG_CACHE_HOME
XDG_DATA_HOME=$XDG_DATA_HOME
XDG_STATE_HOME=$XDG_STATE_HOME
EOF
}
