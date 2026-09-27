# Show system info on new interactive shell start.
# Must run before the p10k instant-prompt block below: instant-prompt caches
# and replays console output, and anything that prints before it initializes
# (per its own comment: "everything else may go below") triggers a
# "Console output during zsh initialization detected" warning.
[[ -o interactive ]] && command -v fastfetch &>/dev/null && fastfetch

# Enable Powerlevel10k instant prompt. Should stay close to the top of this file ($ZDOTDIR/.zshrc).
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# XDG Base Directory: zsh-internal vars that oh-my-zsh only defaults if unset
# (lib/history.zsh and oh-my-zsh.sh's compinit both check `[[ -z "$VAR" ]]`),
# so these MUST be set before the cachyos-config.zsh source line below —
# appending them at the end of this file would be too late.
: ${XDG_CACHE_HOME:=$HOME/.cache}
: ${XDG_STATE_HOME:=$HOME/.local/state}
export HISTFILE="$XDG_STATE_HOME/zsh/history"
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"

[[ -r /usr/share/cachyos-zsh-config/cachyos-config.zsh ]] && source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
[[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.p10k.zsh" ]] || source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.p10k.zsh"

# ============================================================================
# XDG Base Directory + per-app env vars.
# Single source of truth mirrored in two places, keep them identical:
#   - this block
#   - ~/.config/environment.d/10-xdg.conf   (graphical/systemd session)
# (HISTFILE/ZSH_COMPDUMP are set earlier, near the top of this file — see note
# there; they are zsh-internal and don't belong in environment.d.)
# ============================================================================

# --- Base four (guarded: systemd environment.d already exports these for the
# graphical session; this is defensive for shells started outside that context) ---
: ${XDG_CONFIG_HOME:=$HOME/.config}
: ${XDG_DATA_HOME:=$HOME/.local/share}
: ${XDG_STATE_HOME:=$HOME/.local/state}
: ${XDG_CACHE_HOME:=$HOME/.cache}
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME

# --- Per-app relocations ---
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"
export NPM_CONFIG_INIT_MODULE="$XDG_CONFIG_HOME/npm/config/npm-init.js"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export PULSE_COOKIE="$XDG_CONFIG_HOME/pulse/cookie"
export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"

# Added 2026-09-27 (home-dir cleanup): apps that used to create ~/.<name>.
# ZDOTDIR itself is set in /etc/zsh/zshenv (written by scripts/lib-xdg.sh),
# since zsh must know it before it can find this file.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export BUN_INSTALL="$XDG_DATA_HOME/bun"
export BUN_INSTALL_CACHE_DIR="$XDG_CACHE_HOME/bun"
export TRITON_CACHE_DIR="$XDG_CACHE_HOME/triton"

# Future-proofing: cargo/npm put user-installed binaries under these paths.
# Neither exists yet on this machine, but PATH is wired now so `cargo install`
# / `npm install -g` binaries are found the first time they're used.
path=("$CARGO_HOME/bin" "$NPM_CONFIG_PREFIX/bin" $path)

