# ========================
# Powerlevel10k instant prompt
# ========================
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ========================
# XDG-safe history
# ========================
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000

mkdir -p "$XDG_STATE_HOME/zsh"

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS

# ========================
# Plugins
# ========================
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ========================
# Theme
# ========================
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# ========================
# Fastfetch (interactive shells only)
# ========================
if [[ $- == *i* ]]; then
    fastfetch
fi

# ========================
# Powerlevel10k config (XDG)
# ========================
[[ -f ${ZDOTDIR:-$HOME}/p10k.zsh ]] && source ${ZDOTDIR:-$HOME}/p10k.zsh

# ========================
# Android / adb XDG isolation
# ========================
export ANDROID_USER_HOME="$XDG_DATA_HOME/android"
alias adb='HOME="$XDG_DATA_HOME/android" adb'

# ========================
# NVIDIA settings config path
# ========================
alias nvidia-settings='nvidia-settings --config="$XDG_CONFIG_HOME/nvidia/settings"'

# ========================
# Completion
# ========================
autoload -Uz compinit
compinit -i -d "$XDG_CACHE_HOME/zsh/zcompdump"

export HISTFILE="$XDG_STATE_HOME/zsh/history"

