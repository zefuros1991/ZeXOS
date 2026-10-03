# Loaded into bash by ~/.local/bin/zexos-kitty-shell (bash --rcfile), never
# from your bash config: your ~/.bashrc first, then the ZeXOS prompt, then
# the logo redraw on window resizes.

# --rcfile replaces ~/.bashrc, so load yours first.
[ -r ~/.bashrc ] && . ~/.bashrc

__zexos_kitty=${XDG_CONFIG_HOME:-$HOME/.config}/kitty
[ -r "$__zexos_kitty/zexos-prompt.bash" ] && . "$__zexos_kitty/zexos-prompt.bash"
[ "$ZEXOS_TERM_REDRAW" = 1 ] && [ -r "$__zexos_kitty/fastfetch-redraw.bash" ] \
    && . "$__zexos_kitty/fastfetch-redraw.bash"
unset __zexos_kitty
