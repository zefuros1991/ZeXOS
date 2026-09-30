# ZeXOS: put ~/.local/bin on PATH, for every login.
#
# The desktop helpers live there (zshell starts the top bar, launcher and
# wallpaper), and niri, Mango and Hyprland call them by name. CachyOS adds
# this folder for you; plain Arch doesn't, so there the desktop came up
# black with only a mouse pointer. The login screen (SDDM) starts the
# desktop through your login shell, which reads /etc/profile and so this
# file, whether you use bash, zsh or fish.
# systemd's file-hierarchy(7) says ~/.local/bin belongs on PATH.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$PATH:$HOME/.local/bin"; export PATH ;;
esac
