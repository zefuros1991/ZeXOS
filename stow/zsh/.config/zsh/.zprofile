# Runs once at login, when the desktop session starts through zsh.
#
# zsh skips ~/.profile, so add our own program folders to PATH here.
# Without this, scripts in ~/.local/bin and apps installed with npm
# can't be found from the launcher or from keyboard shortcuts.
typeset -U path   # -U: never list the same folder twice
path=(
    "$HOME/.local/bin"
    "${XDG_DATA_HOME:-$HOME/.local/share}/npm/bin"
    $path
)
export PATH
