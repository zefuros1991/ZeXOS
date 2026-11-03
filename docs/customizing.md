# Customizing ZeXOS

What ZeXOS sets up for you, and which files to edit to change it.

## What ZeXOS sets up

### The desktop

| Part | What you get |
|---|---|
| **niri** | Keybinds, window rules, blur and animations already set up |
| **Mango** and **Hyprland** | Compositors you can pick on the login screen instead of niri, with the same keys. See [Three compositors](compositors-and-shells.md#three-compositors). |
| **Noctalia v5** | The bar, launcher, notifications and lock screen. The bar is split into three groups attached to the top edge of the screen. |
| **DankMaterialShell** | A second shell, switched with `Mod+Shift+D`. See [Two desktop shells](compositors-and-shells.md#two-desktop-shells). |
| **roller** | A wallpaper picker (`Mod+W`) |
| **SDDM** with the Pixie theme | A login screen that follows your current wallpaper and shows the ZeXOS logo as its round picture, in your wallpaper's colours. Both change with every wallpaper change and shell switch. |

### Colours from your wallpaper

Noctalia generates the theme from the current wallpaper and applies it to GTK, Qt and KDE apps, kitty, fuzzel and btop. Dolphin's folders (Papirus icons) change colour with it.

A mostly white wallpaper switches the desktop to light mode with grey-scale colours, so text, icons and the terminal stay readable, and the folders turn white. Any other wallpaper switches it back to dark. To choose the mode yourself, create `~/.config/zexos/manual-theme-mode`.

### Apps

| Job | App |
|---|---|
| Terminal | kitty |
| Files | Dolphin |
| Images | Gwenview |
| Text | Neovim |
| Media | VLC |
| Web browser | None chosen for you. `Mod+B` opens whichever is your default. Only on a system with no browser at all (a bare Arch install) is Firefox added. |

### Your shell stays yours

ZeXOS doesn't change your shell or your shell config, so bash, zsh or fish all work as before.

### The terminal

kitty opens with the system info in a box (your distro's own logo, or the ZeXOS Z on a system installed from a ZeXOS ISO) and a two-line prompt with the folder, git branch and time. Both fade between two of the wallpaper's colours and change with it.

This only happens in kitty and only adds to your shell config, never edits it. A prompt you set up yourself (starship, oh-my-posh, powerlevel10k, an oh-my-zsh theme, your own fish prompt) is left alone.

To switch parts off, create an empty file:

| To turn off | Create |
|---|---|
| The prompt | `~/.config/zexos/no-prompt` |
| The system info | `~/.config/zexos/no-fastfetch` |

## Config packages

Your settings live as plain files in `~/.dotfiles/stow/`, one folder per app. [GNU Stow](https://www.gnu.org/software/stow/) links each folder into your home folder, so editing the file in either place changes both.

| Folder | Settings for |
|---|---|
| `btop` | `~/.config/btop` |
| `desktop` | Default apps (`mimeapps.list`), GTK/Qt/KDE settings, `zshell` (the shell switcher) and its `Mod+Shift+D` menu (`~/.config/quickshell/zexos-switcher`), and `zexos-screenshot` (screenshots on Mango and Hyprland) |
| `dms` | The first-start DankMaterialShell settings (copied, never linked) |
| `fastfetch` | `~/.config/fastfetch` (the system info shown in kitty) |
| `fuzzel` | `~/.config/fuzzel` |
| `htop` | `~/.config/htop` |
| `hyprland` | `~/.config/hypr` |
| `input` | Keyboard and touchpad settings read by Qt/KDE apps |
| `kitty` | `~/.config/kitty` |
| `mango` | `~/.config/mango` |
| `niri` | `~/.config/niri` |
| `noctalia` | `~/.config/noctalia` (bar layout, plugins, theming), the SDDM wallpaper-sync script, the light/dark switch and the script that makes the folder icons follow the wallpaper |
| `roller` | `~/.config/roller` and its launcher files |
| `theme` | GTK 3/4, qt5ct, qt6ct and the Noctalia colour files |

### Link one folder again after changing it

Only needed if a link is missing or you added a new file. Replace `<package>` with a folder name from the table.

```bash
cd ~/.dotfiles
stow -d stow -t "$HOME" <package>
```

To remove the links for it:

```bash
stow -D -d stow -t "$HOME" <package>
```

To see what would change first, without changing anything:

```bash
stow -n -v -d stow -t "$HOME" <package>
```

> **Good to know.** Some files in `theme` (and `kdeglobals` in `desktop`) are rewritten live by Noctalia whenever the wallpaper changes. That's expected.

---

[Back to the README](../README.md) · [All docs](README.md)
