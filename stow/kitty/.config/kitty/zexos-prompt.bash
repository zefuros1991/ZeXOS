# The ZeXOS prompt for bash, loaded by ~/.local/bin/zexos-kitty-shell, never
# from your bash config.
#
#   ╭─  ~/Projects/ZeXOS ─  main ─ ✔                01:50:45
#   ╰─❯
#
# No fills: the lines, icons and text run along the wallpaper's two colours,
# one character at a time. The colours follow a wallpaper or shell change at
# the next prompt. Don't want it? Create ~/.config/zexos/no-prompt. It also
# stays out of the way of starship and oh-my-posh.
#
# PS1 only names $__zt_ps1, and bash does not expand what that holds again,
# so a folder called $(something) is shown, never run. The colour codes are
# wrapped in \001 \002 bytes, which is what \[ \] turn into.

__zt_cache=${XDG_CACHE_HOME:-$HOME/.cache}/zexos/term
__zt_loaded=
__zt_E=$'\e' __zt_O=$'\001' __zt_C=$'\002' __zt_N=$'\n'

# No colours yet (zexos-term missing or failing): plain grey, so the prompt
# still works.
__zt_grey() {
    [[ -n $__zt_loaded ]] && return
    local i; __zt_G=() __zt_T=()
    for (( i = 0; i <= 40; i++ )); do __zt_G+=(c0c0c0) __zt_T+=(808080); done
    __zt_WARN=e06c75 __zt_loaded=grey
}

# Re-read the colours when they changed. current.bash names the colour file
# for the wallpaper now; zexos-term rewrites it on every wallpaper change.
__zt_colours() {
    local f key
    { read -r f < "$__zt_cache/current.bash"; } 2>/dev/null
    if [[ -z $f || ! -r $f ]]; then
        f=$(zexos-term prompt bash 2>/dev/null) || { __zt_grey; return; }
    fi
    { read -r key < "$f"; } 2>/dev/null
    [[ $key == "$__zt_loaded" ]] && return
    . "$f" && __zt_loaded=$key
}

# __zt_paint <array> <from> <to> <text>: the text in REPLY, its characters
# along the gradient in <array> from step <from> to <to> (0..40).
__zt_paint() {
    local -n __c=$1
    local a=$2 b=$3 s=$4 out= i k h n=${#4}
    for (( i = 0; i < n; i++ )); do
        (( k = n > 1 ? a + (b - a) * i / (n - 1) : a ))
        h=${__c[k]}
        out+="${__zt_O}${__zt_E}[38;2;$((16#${h:0:2}));$((16#${h:2:2}));$((16#${h:4:2}))m${__zt_C}${s:i:1}"
    done
    REPLY=$out
}

__zt_fg() {
    REPLY="${__zt_O}${__zt_E}[38;2;$((16#${1:0:2}));$((16#${1:2:2}));$((16#${1:4:2}))m${__zt_C}"
}

__zt_prompt() {
    local status=$? out p head tail branch t
    __zt_colours

    # the folder, its last part bold
    p=${PWD/#$HOME/\~}
    (( ${#p} > COLUMNS / 2 )) && p="…/${p#"${p%/*/*}"/}"
    head= tail=$p
    [[ $p == ?*/* ]] && head=${p%/*}/ tail=${p##*/}
    __zt_paint __zt_G 0 3 "╭─ ";            out=$REPLY
    __zt_fg "${__zt_G[4]}";                 out+="$REPLY"$'\U000f0770 '
    __zt_paint __zt_G 5 16 "$head"; out+=$REPLY
    __zt_paint __zt_G 16 22 "$tail"; out+="${__zt_O}${__zt_E}[1m${__zt_C}$REPLY${__zt_O}${__zt_E}[22m${__zt_C}"

    # git, as the next branch
    if branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null); then
        (( ${#branch} > 32 )) && branch="${branch:0:12}…${branch: -12}"
        __zt_paint __zt_G 22 26 " ─ ";      out+=$REPLY
        __zt_fg "${__zt_G[27]}";            out+="$REPLY"$'\U000f062c '
        __zt_paint __zt_G 28 34 "$branch";  out+=$REPLY
    fi

    # how the last command went
    __zt_paint __zt_G 34 38 " ─ ";          out+=$REPLY
    if (( status == 0 )); then
        __zt_fg "${__zt_G[40]}";            out+="${__zt_O}${__zt_E}[1m${__zt_C}$REPLY✔${__zt_O}${__zt_E}[22m${__zt_C}"
    else
        __zt_fg "$__zt_WARN";               out+="${__zt_O}${__zt_E}[1m${__zt_C}$REPLY✘${__zt_O}${__zt_E}[22m${__zt_C} $status"
    fi

    # the time at the right end of line 1
    t=$(printf '%(%H:%M:%S)T' -1)
    __zt_paint __zt_T 0 40 "$t"
    out+="${__zt_O}${__zt_E}7${__zt_E}[$((COLUMNS - ${#t}))G$REPLY${__zt_E}8${__zt_C}"

    # line 2: ╰─❯
    __zt_paint __zt_G 4 24 "╰─";            out+="${__zt_N}$REPLY"
    __zt_fg "${__zt_G[40]}";                out+="${__zt_O}${__zt_E}[1m${__zt_C}$REPLY❯${__zt_O}${__zt_E}[0m${__zt_C} "
    __zt_ps1=$out
}

if [[ ! -e ${XDG_CONFIG_HOME:-$HOME/.config}/zexos/no-prompt && -z $STARSHIP_SHELL && -z $POSH_SHELL ]]; then
    __zt_colours
    PROMPT_COMMAND=(__zt_prompt "${PROMPT_COMMAND[@]}")
    PS1='${__zt_ps1}'
fi
