# The ZeXOS prompt for zsh, loaded by ~/.config/kitty/zexos-zsh/.zshenv
# after your own zsh config, never from it. Same look as zexos-prompt.bash:
#
#   ╭─  ~/Projects/ZeXOS ─  main ─ ✔
#   ╰─❯                                   01:50:45
#
# The colours follow a wallpaper or shell change at the next prompt. Don't
# want it? Create ~/.config/zexos/no-prompt. It also stays out of the way of
# starship, oh-my-posh, powerlevel10k and oh-my-zsh themes.
#
# PROMPT only names $__zt_ps1 (prompt_subst), and zsh does not expand what
# that holds again, so a folder called $(something) is shown, never run.

typeset -g __zt_cache=${XDG_CACHE_HOME:-$HOME/.cache}/zexos/term
typeset -g __zt_loaded= __zt_ps1= __zt_rps1=

# No colours yet (zexos-term missing or failing): plain grey, so the prompt
# still works.
__zt_grey() {
    [[ -n $__zt_loaded ]] && return
    typeset -ga __zt_G __zt_T
    __zt_G=(${(s: :)${(l:41*7::c0c0c0 :)}})
    __zt_T=(${(s: :)${(l:41*7::808080 :)}})
    typeset -g __zt_WARN=e06c75 __zt_loaded=grey
}

# Re-read the colours when they changed (see zexos-prompt.bash).
__zt_colours() {
    local f key
    { read -r f < $__zt_cache/current.zsh } 2>/dev/null
    if [[ -z $f || ! -r $f ]]; then
        f=$(zexos-term prompt zsh 2>/dev/null) || { __zt_grey; return }
    fi
    { read -r key < $f } 2>/dev/null
    [[ $key == "$__zt_loaded" ]] && return
    source $f && __zt_loaded=$key
}

# One colour as a zsh prompt escape, in REPLY.
__zt_fg() {
    REPLY="%{"$'\e'"[38;2;$((16#${1[1,2]}));$((16#${1[3,4]}));$((16#${1[5,6]}))m%}"
}

# __zt_paint <array> <from> <to> <text>: the text in REPLY, its characters
# along the gradient in <array> from step <from> to <to> (0..40). zsh counts
# from 1, so step k is element k+1.
__zt_paint() {
    local -a c; c=("${(@P)1}")
    local a=$2 b=$3 s=$4 out= i k ch n=${#4}
    for (( i = 1; i <= n; i++ )); do
        (( k = n > 1 ? a + (b - a) * (i - 1) / (n - 1) : a ))
        __zt_fg ${c[k + 1]}
        ch=${s[i]}
        [[ $ch == % ]] && ch=%%
        out+=$REPLY$ch
    done
    REPLY=$out
}

__zt_prompt() {
    local st=$? out p head tail branch t
    __zt_colours

    # the folder, its last part bold
    p=${PWD/#$HOME/\~}
    (( ${#p} > COLUMNS / 2 )) && p="…/${p:h:t}/${p:t}"
    head= tail=$p
    [[ $p == ?*/* ]] && head=${p%/*}/ tail=${p##*/}
    __zt_paint __zt_G 0 3 "╭─ ";            out=$REPLY
    __zt_fg ${__zt_G[5]};                   out+=$REPLY$'\uf07c '
    __zt_paint __zt_G 5 16 "$head";         out+=$REPLY
    __zt_paint __zt_G 16 22 "$tail";        out+="%B$REPLY%b"

    # git, as the next branch
    if branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null); then
        (( ${#branch} > 32 )) && branch="${branch[1,12]}…${branch[-12,-1]}"
        __zt_paint __zt_G 22 26 " ─ ";      out+=$REPLY
        __zt_fg ${__zt_G[28]};              out+=$REPLY$'\ue725 '
        __zt_paint __zt_G 28 34 "$branch";  out+=$REPLY
    fi

    # how the last command went
    __zt_paint __zt_G 34 38 " ─ ";          out+=$REPLY
    if (( st == 0 )); then
        __zt_fg ${__zt_G[41]};              out+="%B$REPLY✔%b"
    else
        __zt_fg $__zt_WARN;                 out+="%B$REPLY✘%b $st"
    fi

    # line 2: ╰─❯, and the time on the right
    __zt_paint __zt_G 4 24 "╰─";            out+=$'\n'$REPLY
    __zt_fg ${__zt_G[41]};                  out+="%B$REPLY❯%b%f "
    __zt_ps1=$out
    t=${(%):-%D{%H:%M:%S}}
    __zt_paint __zt_T 0 40 "$t";            __zt_rps1="$REPLY%f"
}

if [[ ! -e ${XDG_CONFIG_HOME:-$HOME/.config}/zexos/no-prompt && -z $STARSHIP_SHELL \
      && -z $POSH_SHELL && -z $ZSH_THEME ]] && (( ! $+functions[p10k] )); then
    setopt prompt_subst prompt_percent
    precmd_functions=(__zt_prompt $precmd_functions)
    PROMPT='${__zt_ps1}'
    RPROMPT='${__zt_rps1}'
fi
