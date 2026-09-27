# Login-shell setup (runs once when SDDM starts the desktop session through zsh).
# zsh does not read ~/.profile, so add ~/.local/bin and the npm bin dir to the
# session PATH here, or user scripts go missing from the niri launcher and keybinds.
typeset -U path
path=("$HOME/.local/bin" "${XDG_DATA_HOME:-$HOME/.local/share}/npm/bin" $path)
export PATH
