# The ZeXOS prompt for fish, loaded by ~/.local/bin/zexos-kitty-shell, never
# from your fish config. Same look as zexos-prompt.bash:
#
#   ╭─  ~/Projects/ZeXOS ─  main ─ ✔
#   ╰─❯                                   01:50:45
#
# The colours follow a wallpaper or shell change at the next prompt. Don't
# want it? Create ~/.config/zexos/no-prompt. It also leaves a prompt you made
# yourself (anything outside /usr/share) alone, and starship or oh-my-posh.

set -g __zt_cache (set -q XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo $HOME/.cache)/zexos/term
set -g __zt_loaded ''

# No colours yet (zexos-term missing or failing): plain grey, so the prompt
# still works.
function __zt_grey
    test -n "$__zt_loaded"; and return
    set -g __zt_G (string split " " (string repeat -n 41 "c0c0c0 " | string trim))
    set -g __zt_T (string split " " (string repeat -n 41 "808080 " | string trim))
    set -g __zt_WARN e06c75
    set -g __zt_loaded grey
end

# Re-read the colours when they changed (see zexos-prompt.bash).
function __zt_colours
    set -l f (cat $__zt_cache/current.fish 2>/dev/null)
    if test -z "$f"; or not test -r "$f"
        command -q zexos-term; and set f (zexos-term prompt fish 2>/dev/null)
        or begin; __zt_grey; return; end
    end
    set -l key (head -n1 $f 2>/dev/null)
    test "$key" = "$__zt_loaded"; and return
    source $f
    set -g __zt_loaded $key
end

# __zt_paint <array name> <from> <to> <text>: prints the text, its characters
# along the gradient from step <from> to <to> (0..40). fish counts from 1, so
# step k is element k+1.
function __zt_paint
    set -l c $$argv[1]
    set -l a $argv[2]
    set -l b $argv[3]
    set -l chars (string split '' -- "$argv[4]")
    set -l n (count $chars)
    for i in (seq $n)
        set -l k $a
        test $n -gt 1; and set k (math --scale=0 "$a + ($b - $a) * ($i - 1) / ($n - 1)")
        set_color $c[(math $k + 1)]
        printf '%s' $chars[$i]
    end
end

function __zt_icon
    set_color $argv[1]
    printf '%s ' $argv[2]
end

if not test -e (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/zexos/no-prompt
    and not set -q STARSHIP_SHELL; and not set -q POSH_SHELL
    and string match -qr '^(embedded:|/usr/share/|n/a$)' -- (functions --details fish_prompt)
    __zt_colours

    function fish_prompt
        set -l st $status
        __zt_colours

        # the folder, its last part bold
        set -l p (string replace -r -- '^'(string escape --style=regex $HOME) '~' $PWD)
        if test (string length -- $p) -gt (math --scale=0 "$COLUMNS / 2")
            set -l parts (string split / -- $p)
            set p "…/$parts[-2]/$parts[-1]"
        end
        set -l head ''
        set -l tail $p
        if string match -qr '^.+/' -- $p
            set head (string replace -r '[^/]*$' '' -- $p)
            set tail (string replace -r '^.*/' '' -- $p)
        end
        __zt_paint __zt_G 0 3 "╭─ "
        __zt_icon $__zt_G[5] \uf07c
        __zt_paint __zt_G 5 16 "$head"
        set_color --bold
        __zt_paint __zt_G 16 22 "$tail"
        set_color normal

        # git, as the next branch
        set -l branch (git symbolic-ref --short -q HEAD 2>/dev/null; or git rev-parse --short HEAD 2>/dev/null)
        if test -n "$branch"
            if test (string length -- $branch) -gt 32
                set branch (string sub -l 12 -- $branch)…(string sub -s -12 -- $branch)
            end
            __zt_paint __zt_G 22 26 " ─ "
            __zt_icon $__zt_G[28] \ue725
            __zt_paint __zt_G 28 34 "$branch"
        end

        # how the last command went
        __zt_paint __zt_G 34 38 " ─ "
        if test $st -eq 0
            set_color --bold $__zt_G[41]; printf '✔'
        else
            set_color --bold $__zt_WARN; printf '✘'
            set_color normal; set_color $__zt_WARN; printf ' %s' $st
        end
        set_color normal

        # line 2
        printf '\n'
        __zt_paint __zt_G 4 24 "╰─"
        set_color --bold $__zt_G[41]; printf '❯'
        set_color normal; printf ' '
    end

    function fish_right_prompt
        __zt_paint __zt_T 0 40 (date +%H:%M:%S)
        set_color normal
    end
end
