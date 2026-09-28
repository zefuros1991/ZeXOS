# zsh settings for every terminal you open.
# The order of the steps below matters, so add new things at the end.

# ── 1. System info banner ──────────────────────────────
# Has to come first. The fast prompt in step 2 complains if anything
# prints text after it starts.
if [[ -o interactive ]] && command -v fastfetch &>/dev/null; then
  fastfetch
fi

# ── 2. Fast prompt ─────────────────────────────────────
# Powerlevel10k draws the prompt straight away while the rest loads.
# Anything that asks you a question (passwords, y/n) must go above this.
p10k_cache="${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
if [[ -r $p10k_cache ]]; then
  source "$p10k_cache"
fi
unset p10k_cache

# ── 3. Where zsh keeps its own files ───────────────────
# Must be set before step 4, which only fills these in when they're empty.
: ${XDG_CACHE_HOME:=$HOME/.cache}
: ${XDG_STATE_HOME:=$HOME/.local/state}
export HISTFILE="$XDG_STATE_HOME/zsh/history"                      # command history
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"    # tab-completion cache

# ── 4. CachyOS defaults ────────────────────────────────
# Plugins, aliases and tab completion that come with CachyOS.
# Other Arch-based systems don't have that package, so the same plugins
# are loaded one by one instead (the installer puts them there).
cachyos_zsh=/usr/share/cachyos-zsh-config/cachyos-config.zsh
if [[ -r $cachyos_zsh ]]; then
  source "$cachyos_zsh"
else
  mkdir -p "${HISTFILE:h}" "${ZSH_COMPDUMP:h}"
  HISTSIZE=50000 SAVEHIST=10000
  setopt extended_history hist_expire_dups_first hist_ignore_dups \
         hist_ignore_space hist_verify share_history
  autoload -Uz compinit && compinit -d "$ZSH_COMPDUMP"
  zstyle ':completion:*' menu select
  for zexos_zsh in \
      /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme \
      /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
      /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh \
      /usr/share/doc/pkgfile/command-not-found.zsh \
      /usr/share/fzf/key-bindings.zsh /usr/share/fzf/completion.zsh \
      /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -r $zexos_zsh ]] && source "$zexos_zsh"
  done
  unset zexos_zsh
  if (( $+widgets[history-substring-search-up] )); then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
  fi
fi
unset cachyos_zsh

# ── 5. Prompt look ─────────────────────────────────────
# Change it with `p10k configure`.
p10k_theme="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.p10k.zsh"
[[ -f $p10k_theme ]] && source "$p10k_theme"
unset p10k_theme

# ── 6. Keep the home folder tidy ───────────────────────
# Tell apps to store their files under ~/.config, ~/.local and ~/.cache
# instead of making new ~/.something folders.
# The same list lives in ~/.config/environment.d/10-xdg.conf for the
# desktop session; keep the two in step.

# The four standard folders. The desktop sets these already; this covers
# shells started some other way (for example over SSH).
: ${XDG_CONFIG_HOME:=$HOME/.config}
: ${XDG_DATA_HOME:=$HOME/.local/share}
: ${XDG_STATE_HOME:=$HOME/.local/state}
: ${XDG_CACHE_HOME:=$HOME/.cache}
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME

# zsh (also set in /etc/zsh/zshenv, because zsh needs it to find this file)
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Rust
export CARGO_HOME="$XDG_DATA_HOME/cargo"

# Node.js / npm
export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_INIT_MODULE="$XDG_CONFIG_HOME/npm/config/npm-init.js"

# Bun
export BUN_INSTALL="$XDG_DATA_HOME/bun"
export BUN_INSTALL_CACHE_DIR="$XDG_CACHE_HOME/bun"

# NVIDIA and AI tools
export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"
export TRITON_CACHE_DIR="$XDG_CACHE_HOME/triton"

# Other
export PULSE_COOKIE="$XDG_CONFIG_HOME/pulse/cookie"
export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"

# Programs installed with `cargo install` or `npm install -g` land here.
path=("$CARGO_HOME/bin" "$NPM_CONFIG_PREFIX/bin" $path)
