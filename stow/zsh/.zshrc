# Show system info on new interactive shell start.
# Must run before the p10k instant-prompt block below: instant-prompt caches
# and replays console output, and anything that prints before it initializes
# (per its own comment: "everything else may go below") triggers a
# "Console output during zsh initialization detected" warning.
[[ -o interactive ]] && command -v fastfetch &>/dev/null && fastfetch

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
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

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
[[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.p10k.zsh" ]] || source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.p10k.zsh"

# GPU MUX switching via asus-armoury: gpu-game = dGPU-only, gpu-battery = hybrid.
# A mux flip only takes effect after a reboot (ACPI limitation), so these
# reboot automatically — Ctrl-C during the countdown to cancel.
# Also keeps niri's render-drm-device line in rules.kdl in sync: the AMD render
# node only exists in hybrid mode, so the line must be commented out for
# dGPU-only (niri fails to start otherwise) and active for hybrid (or the dGPU
# never runtime-suspends).
_gpu-mux-set() {
  local target=$1 label=$2
  local attr=/sys/class/firmware-attributes/asus-armoury/attributes/gpu_mux_mode/current_value
  local rules=~/.dotfiles/stow/niri/.config/niri/cfg/rules.kdl
  if [[ $(<$attr) == $target ]]; then
    echo "Already in $label mode — nothing to do."
    return 0
  fi
  if [[ $target == 0 ]]; then
    sed -i 's|^\([[:space:]]*\)render-drm-device |\1// render-drm-device |' $rules
    grep -qE '^[[:space:]]*render-drm-device ' $rules && { echo "Failed to comment out render-drm-device in $rules — not switching."; return 1 }
  else
    sed -i 's|^\([[:space:]]*\)// render-drm-device |\1render-drm-device |' $rules
    grep -qE '^[[:space:]]*render-drm-device ' $rules || { echo "Failed to restore render-drm-device in $rules — not switching."; return 1 }
  fi
  echo "niri render-drm-device synced for $label."
  if ! asusctl armoury set gpu_mux_mode $target; then
    echo "asusctl failed — reverting niri config, not rebooting."
    if [[ $target == 0 ]]; then
      sed -i 's|^\([[:space:]]*\)// render-drm-device |\1render-drm-device |' $rules
    else
      sed -i 's|^\([[:space:]]*\)render-drm-device |\1// render-drm-device |' $rules
    fi
    return 1
  fi
  echo "MUX set to $label. Rebooting in 5s — Ctrl-C to cancel."
  sleep 5 && systemctl reboot
}
gpu-game()    { _gpu-mux-set 0 "dGPU-only (game)"; }
gpu-battery() { _gpu-mux-set 1 "hybrid (battery)"; }

# ============================================================================
# XDG Base Directory + per-app env vars.
# Single source of truth mirrored in three places, keep them identical:
#   - this block
#   - ~/.config/fish/conf.d/xdg.fish
#   - ~/.config/environment.d/10-xdg.conf   (graphical/systemd session)
# Written 2026-07-12 during the XDG cleanup pass. See /home/zefuros/dotbackup/MANIFEST.md.
# (HISTFILE/ZSH_COMPDUMP are set earlier, near the top of this file — see note
# there; they are zsh-internal and don't belong in fish/environment.d.)
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

# Future-proofing: cargo/npm put user-installed binaries under these paths.
# Neither exists yet on this machine, but PATH is wired now so `cargo install`
# / `npm install -g` binaries are found the first time they're used.
path=("$CARGO_HOME/bin" "$NPM_CONFIG_PREFIX/bin" $path)
