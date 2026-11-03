# Customizing ZeXOS

## What ZeXOS sets up

- **niri**, with keybinds, window rules, blur and animations already set up
- **Noctalia v5** as the bar, launcher, notifications and lock screen. It uses a lightly patched build (`packaging/noctalia-zexos`) that attaches the three bar "islands" to the top edge and adds a launcher-only size option.
- **Colours from your wallpaper**: Noctalia generates the theme from the current wallpaper and applies it to GTK, Qt and KDE apps, kitty, fuzzel and btop. Dolphin's folders (Papirus icons) change colour with it. A mostly white wallpaper switches the desktop to light mode with grey-scale colours, so text, icons and the terminal stay readable, and the folders turn white; any other wallpaper switches it back to dark (to choose the mode yourself, create `~/.config/zexos/manual-theme-mode`)
- **Mango** and **Hyprland** as compositors you can pick at the login screen instead of niri, with the same keys (see [Three compositors](compositors-and-shells.md#three-compositors))
- **DankMaterialShell** as a second shell you can switch to with `Mod+Shift+D` (see [Two desktop shells](compositors-and-shells.md#two-desktop-shells))
- **roller**, a wallpaper picker (`Mod+W`)
- **SDDM** with the Pixie theme; the login screen follows your current wallpaper and shows the ZeXOS logo as its round picture, in your wallpaper's colours; both change with every wallpaper change and shell switch (`packaging/pixie-sddm-zexos/make-avatar.py` draws the six avatars)
- Everyday apps: **kitty** (terminal), **Dolphin** (files), **Gwenview** (images), **Neovim** (text), **VLC** (media)
- No browser is chosen for you: keep the one you have. `Mod+B` opens whichever browser is set as your default. Only if the system has no browser at all (a bare Arch install) is Firefox added
- Your shell stays yours: ZeXOS doesn't change it or your shell config, so bash, zsh or fish all work as before
- **A terminal in your wallpaper's colours**: kitty opens with the system info (your distro's own logo, or the ZeXOS Z on a system installed from a ZeXOS ISO) in a box, and a two-line prompt with the folder, git branch and time. Both fade between two of the wallpaper's colours and change with it. This only happens in kitty and only adds to your shell config, never edits it: a prompt you set up yourself (starship, oh-my-posh, powerlevel10k, an oh-my-zsh theme, your own fish prompt) is left alone. To turn the prompt off, create `~/.config/zexos/no-prompt`; for no system info, `~/.config/zexos/no-fastfetch`

## Config packages

Every folder under `stow/` is one Stow package, a slice of your home folder that lives in this repo.

| Package | Manages |
|---|---|
| `btop` | `~/.config/btop` |
| `desktop` | default apps (`mimeapps.list`), GTK/Qt/KDE settings, `zshell` (the shell switcher) and its `Mod+Shift+D` menu (`~/.config/quickshell/zexos-switcher`) and `zexos-screenshot` (screenshots on Mango and Hyprland) |
| `dms` | the first-start DankMaterialShell settings (copied, never linked) |
| `fastfetch` | `~/.config/fastfetch` (the system info shown in kitty) |
| `fuzzel` | `~/.config/fuzzel` |
| `htop` | `~/.config/htop` |
| `input` | keyboard and touchpad settings read by Qt/KDE apps |
| `kitty` | `~/.config/kitty` |
| `hyprland` | `~/.config/hypr` |
| `mango` | `~/.config/mango` |
| `niri` | `~/.config/niri` |
| `noctalia` | `~/.config/noctalia` (bar layout, plugins, theming), the SDDM wallpaper-sync script, the light/dark switch and the script that makes the folder icons follow the wallpaper |
| `roller` | `~/.config/roller` and its launcher files |
| `theme` | GTK 3/4, qt5ct, qt6ct and the Noctalia colour files |

To relink a single package after editing it:

```bash
cd ~/.dotfiles
stow -d stow -t "$HOME" <package>       # link
stow -D -d stow -t "$HOME" <package>    # unlink
stow -n -v -d stow -t "$HOME" <package> # dry run: show what would change
```

Some files in `theme` (and `kdeglobals` in `desktop`) are rewritten live by Noctalia whenever the wallpaper changes. That's expected.

---

[Back to the README](../README.md) · [All docs](README.md)
