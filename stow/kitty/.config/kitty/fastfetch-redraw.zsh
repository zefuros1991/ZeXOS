# Loaded into zsh by ~/.config/kitty/zexos-zsh/.zshenv, never from your zsh
# config. Same job as fastfetch-redraw.fish: until you run your first
# command, it draws the logo again whenever tiling changes the window's
# size, so it doesn't break up.

TRAPWINCH() {
    print -n '\e[H\e[2J\e[3J'   # clear the screen and scrollback
    zexos-fetch
    zle && zle reset-prompt
}

# After your first command, stop redrawing.
__zexos_ff_stop() {
    unfunction TRAPWINCH __zexos_ff_stop
    preexec_functions=(${preexec_functions:#__zexos_ff_stop})
}
preexec_functions+=(__zexos_ff_stop)
