# XDG Base Directory + per-app env vars.
# Single source of truth mirrored in three places, keep them identical:
#   - ~/.config/fish/conf.d/xdg.fish        (this file)
#   - ~/.zshrc                              (marked "XDG Base Directory" block)
#   - ~/.config/environment.d/10-xdg.conf   (graphical/systemd session, GUI apps under niri)
# Written 2026-07-12 during the XDG cleanup pass. See /home/zefuros/dotbackup/MANIFEST.md.

# --- Base four (guarded: systemd environment.d already exports these for the
# graphical session: this is defensive for shells started outside that context) ---
if not set -q XDG_CONFIG_HOME
    set -gx XDG_CONFIG_HOME $HOME/.config
end
if not set -q XDG_DATA_HOME
    set -gx XDG_DATA_HOME $HOME/.local/share
end
if not set -q XDG_STATE_HOME
    set -gx XDG_STATE_HOME $HOME/.local/state
end
if not set -q XDG_CACHE_HOME
    set -gx XDG_CACHE_HOME $HOME/.cache
end

# --- Per-app relocations ---
set -gx CARGO_HOME $XDG_DATA_HOME/cargo
set -gx CUDA_CACHE_PATH $XDG_CACHE_HOME/nv
set -gx NPM_CONFIG_CACHE $XDG_CACHE_HOME/npm
set -gx NPM_CONFIG_PREFIX $XDG_DATA_HOME/npm
set -gx NPM_CONFIG_INIT_MODULE $XDG_CONFIG_HOME/npm/config/npm-init.js
set -gx NPM_CONFIG_USERCONFIG $XDG_CONFIG_HOME/npm/npmrc
set -gx PULSE_COOKIE $XDG_CONFIG_HOME/pulse/cookie
set -gx WGETRC $XDG_CONFIG_HOME/wget/wgetrc

# Future-proofing: cargo/npm put user-installed binaries under these paths.
# Neither exists yet on this machine, but PATH is wired now so `cargo install`
# / `npm install -g` binaries are found the first time they're used.
fish_add_path -g $CARGO_HOME/bin
fish_add_path -g $NPM_CONFIG_PREFIX/bin
