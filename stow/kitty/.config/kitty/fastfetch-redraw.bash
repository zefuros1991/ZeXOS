# Loaded into bash by ~/.local/bin/zexos-kitty-shell (bash --rcfile), never
# from your bash config. It does the same job as fastfetch-redraw.fish: until
# you run your first command, it draws fastfetch again whenever tiling
# changes the window's size, so the logo doesn't break up.

# --rcfile replaces ~/.bashrc, so load yours first.
[ -r ~/.bashrc ] && . ~/.bashrc

__zexos_ff_redraw() {
    printf '\e[H\e[2J\e[3J'   # clear the screen and scrollback
    fastfetch
    printf '%s' "${PS1@P}"    # put the prompt back
}

# The first prompt is the one you start at; the second comes after your
# first command. At that point, stop redrawing.
__zexos_ff_prompts=0
__zexos_ff_stop() {
    (( ++__zexos_ff_prompts < 2 )) && return
    trap - WINCH
    PROMPT_COMMAND=("${PROMPT_COMMAND[@]/__zexos_ff_stop}")
}
PROMPT_COMMAND+=(__zexos_ff_stop)
trap __zexos_ff_redraw WINCH
