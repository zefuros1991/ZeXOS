# Compositors and shells

Two things shape how ZeXOS looks and behaves. Pick them to taste, and switch any time.

- A **desktop shell** is the top bar, launcher, notifications and lock screen.
- A **compositor** draws and arranges your windows.

## Two desktop shells

ZeXOS installs two shells: [Noctalia](https://noctalia.dev) and [DankMaterialShell](https://danklinux.com) (DMS). Noctalia is the default.

| | Noctalia | DankMaterialShell |
|---|---|---|
| Default | Yes | No |
| Bar layout | Three groups | The same items in the same order, grouped in three |
| USB drive button | Yes | No (drives still mount from Dolphin) |
| "Restart to UEFI" in the power menu | Yes | No |
| Animated wallpapers | Plays them | Shows the first frame as a still |
| Colours follow the wallpaper | By itself | Through a small watcher, `zexos-dms-sync` |

### Switch shell

1. Press `Mod+Shift+D`, or click the ⇄ button at the right end of the bar (it is in both shells).
2. Pick a shell from the menu.

The other shell closes and the new one starts right away. Your choice is saved in `~/.config/zexos/shell`, so it is still there after a log out or restart. Each user on the machine has their own.

From a terminal, the same thing:

```bash
zshell switch dms
zshell switch noctalia
```

The switch is animated. The screen fades to a dark shade of the old wallpaper's main colour with the new shell's logo in the middle, the colour turns into the new wallpaper's shade while the shells swap behind it, then it fades out to the new desktop. You never see a grey or black gap, even with an animated wallpaper.

### Why the keys are the same in both

The keybinds call a small helper, `zshell`, instead of a shell directly. It sends each action (launcher, lock, volume, wallpaper, ...) to whichever shell is running. `zshell --help` lists them.

### Change the animations

`zexos-motion` lists the choices. They look the same on all three compositors and in both shells.

| You can change | Default |
|---|---|
| The switch animation | Colours plus logo |
| How windows open and close | Zoom |
| How workspaces move | Pick in `zexos-motion` |
| How fast the shells' panels slide | Pick in `zexos-motion` |

For the switch animation:

```bash
zexos-motion set switch dip    # keep the colours, drop the logo
zexos-motion set switch none   # no animation
```

### How DMS gets its look

The first time DMS starts, it is set up to look like Noctalia:

- The same bar items in the same order, in three groups: CPU use and updates on the left; workspaces, clock and music in the middle; tray, quick settings, notifications, battery and the shell switcher on the right
- The same font sizes and the ZeXOS wallpaper

After that, changes you make in DMS's own settings are kept.

### Colours follow the wallpaper

In both shells, these change with the wallpaper: window borders, kitty, Dolphin and other KDE apps, GTK apps, fuzzel menus, btop, the folder icons and the login screen. A very bright wallpaper switches to light mode. To choose dark or light yourself, create `~/.config/zexos/manual-theme-mode`.

GTK apps that are already open (like Shelly) keep their old colours until you close and reopen them, because GTK only reads its colours when an app starts. Open KDE apps, kitty and the rest change by themselves.

### The window frame

The window you're using gets a frame that fades between two of the wallpaper's colours. The others get a thin, faint line and are dimmed a little, so your eye lands on the right one. This works the same in both shells on niri and Hyprland. Mango can only draw a frame in one colour, so there it is one colour plus the same dimming.

## Three compositors

You pick one on the login screen, in the session menu next to the password box.

| | niri | Mango | Hyprland |
|---|---|---|---|
| Default | Yes | No | No |
| How windows are arranged | A row that scrolls sideways | Same as niri | **Tiles**: every new window takes half of the one you're in |
| Window width | Each window's own | Half the screen at first | Nothing is ever off screen |
| Overview | Built in | ZeXOS's own ([mango-overview](https://github.com/zefuros1991/mango-overview)) | ZeXOS's own ([mango-overview](https://github.com/zefuros1991/mango-overview)) |
| Config folder | `~/.config/niri` | `~/.config/mango` | `~/.config/hypr` (written in Lua) |
| Both shells work | Yes | Yes | Yes |
| Window colours follow the wallpaper | Yes | Yes | Yes |

Links: [niri](https://github.com/YaLTeR/niri) · [Mango](https://github.com/mangowm/mango) · [Hyprland](https://hypr.land)

Mango and Hyprland have the same gaps, borders, round corners, blur and keys as niri. Hyprland is the odd one out on purpose: instead of scrolling, it tiles, side by side on wide windows and one above the other on tall ones, like folding a sheet of paper in half and then in half again. `Mod+J` flips a split between side by side and one above the other.

### Overview on Mango and Hyprland

Neither has an overview like niri's, so ZeXOS adds its own. It shows every workspace as a card with live window previews.

| To | Do this |
|---|---|
| Open it | `Mod+O`, or four fingers up |
| Move a window to another workspace | Drag it onto that workspace |
| Go through the workspaces | Swipe three fingers up or down |
| Go through the windows | Swipe sideways (one swipe can cross several) |
| Go to one | Press `Enter` or click it |
| Close it | `Esc`, or four fingers down |

Mango's own built-in overview is still on `Mod+Shift+O`.

### What is different in Mango

- Workspaces are Mango's "tags" 1 to 9. Each screen has its own. `Mod+Tab` goes back to the last one.
- No jump to the first or last window (`Mod+Home`/`Mod+End`), and no keys to make a window taller or shorter.
- `Mod+Minus` and `Mod+Equal` step through set widths (a quarter, a third, a half, two thirds, three quarters, full) instead of 10% at a time.
- `Mod+Shift+Escape` shows the same cheat sheet as `Mod+F1`, because niri's own hotkey overlay doesn't exist there. Under Noctalia it is a simple searchable list.
- Screenshots use `zexos-screenshot` (grim and slurp) and are saved and copied the same way.

### What is different in Hyprland

- No jump to the first or last window (`Mod+Home`/`Mod+End`).
- `Mod+Minus` and `Mod+Equal` move the line between two windows left or right by 100 pixels (with Shift, up or down). One window grows and its neighbour shrinks.
- `Mod+Shift+Escape` shows the same cheat sheet as `Mod+F1`.
- The config is `hyprland.lua` plus the files in `cfg/`.

---

[Back to the README](../README.md) · [All docs](README.md)
