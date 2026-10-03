# zsh reads this because ~/.local/bin/zexos-kitty-shell points ZDOTDIR here.
# It puts your ZDOTDIR back right away, so zsh goes on to read your own
# .zshenv, .zshrc and the rest as usual. Once those have run, just before
# the first prompt, it adds the ZeXOS prompt and the logo redraw.

if [[ -n ${ZEXOS_ORIG_ZDOTDIR+X} ]]; then
    export ZDOTDIR=$ZEXOS_ORIG_ZDOTDIR
    unset ZEXOS_ORIG_ZDOTDIR
else
    unset ZDOTDIR
fi
typeset -g __zexos_kitty=${${(%):-%x}:A:h:h}
[[ -r ${ZDOTDIR:-$HOME}/.zshenv ]] && source ${ZDOTDIR:-$HOME}/.zshenv

if [[ -o interactive ]]; then
    __zexos_setup() {
        precmd_functions=(${precmd_functions:#__zexos_setup})
        unfunction __zexos_setup
        [[ -r $__zexos_kitty/zexos-prompt.zsh ]] && source $__zexos_kitty/zexos-prompt.zsh
        # our prompt must run before everything else this first time too
        (( $+functions[__zt_prompt] )) && __zt_prompt
        [[ $ZEXOS_TERM_REDRAW == 1 && -r $__zexos_kitty/fastfetch-redraw.zsh ]] \
            && source $__zexos_kitty/fastfetch-redraw.zsh
        unset __zexos_kitty
    }
    # added last, so it runs after anything your .zshrc adds
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd __zexos_setup
fi
