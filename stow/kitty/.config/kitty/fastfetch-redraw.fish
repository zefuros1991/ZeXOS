# Loaded into fish by ~/.local/bin/zexos-kitty-shell (fish -C), never from
# your fish config. fastfetch draws its logo and info side by side once, at
# the window's width. When tiling later makes the window smaller, kitty
# re-wraps those lines and the logo breaks up. So until you run your first
# command, this draws fastfetch again whenever the window changes size.

function __zexos_ff_redraw --on-signal WINCH
    # Only while the command line is still empty.
    test -z "$(commandline)"; or return
    printf '\e[H\e[2J\e[3J'   # clear the screen and scrollback
    fastfetch
    commandline -f repaint
end

# After your first command, stop redrawing.
function __zexos_ff_stop --on-event fish_preexec
    functions -e __zexos_ff_redraw __zexos_ff_stop
end
