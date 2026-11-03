# Compositors and shells

## Two desktop shells

ZeXOS installs two desktop shells (the top bar, launcher, notifications and lock screen): [Noctalia](https://noctalia.dev) and [DankMaterialShell](https://danklinux.com) (DMS). Noctalia is the default.

Press `Mod+Shift+D`, or click the ⇄ button at the right end of the bar (it is in both shells), and pick one from the menu. The other shell closes and the new one starts right away. Your choice is saved in `~/.config/zexos/shell`, so it is still there after you log out or restart, and every user on the machine has their own.

The switch itself is animated: the screen fades to a dark shade of the old wallpaper's main colour with the new shell's logo large in the middle, that colour slowly turns into the new wallpaper's shade while the shells swap behind it, and then it fades out to the new desktop. You never see a grey or black gap, even with an animated wallpaper. `zexos-motion set switch dip` keeps the colours but drops the logo, and `none` switches with no animation.

How windows open and close (they zoom by default), how workspaces move and how fast the shells' panels slide can be picked the same way, and look the same on all three compositors and in both shells: `zexos-motion` lists the choices.

Both use the same keys, because the keybinds call a small helper, `zshell`, instead of a shell directly. `zshell` sends each action (launcher, lock, volume, wallpaper, ...) to whichever shell is running. `zshell --help` lists them, and `zshell switch dms` or `zshell switch noctalia` does the same as the menu from a terminal.

The first time DMS starts it gets a ZeXOS look copied from `stow/dms/.local/share/zexos/dms/`: the same bar items as Noctalia, in the same order, grouped in three like Noctalia's islands: CPU use and updates on the left, DMS's Dank Island in the middle (workspaces, clock, music), and tray, quick settings, notifications, battery and the shell switcher on the right. Each side shares one background, set with DMS's own island settings (no patch). It also gets the same font sizes and the ZeXOS wallpaper. It's a copy, so changes you make in DMS's own settings are kept.

The window you're using gets a frame that fades between two of the wallpaper's colours. The others get a thin, faint line and are dimmed a little, so your eye lands on the right one. That works the same in both shells on niri and Hyprland. Mango can only draw a frame in one colour, so there it's one colour plus the same dimming.

Everything follows the wallpaper in both shells: window borders, kitty, Dolphin and other KDE apps, GTK apps, fuzzel menus, btop, the folder icons and the login screen. A very bright wallpaper switches to light mode. Noctalia does this by itself; for DMS a small watcher, `zexos-dms-sync`, does the parts DMS doesn't (`systemctl --user status zexos-dms-sync.path`). To pick dark or light mode yourself, create `~/.config/zexos/manual-theme-mode`. GTK apps that are already open (like Shelly) keep their old colours until you close and reopen them, because GTK only reads its colours when an app starts; Noctalia's own docs say the same. Open KDE apps, kitty and the rest change by themselves.

What DMS can't do yet, compared to Noctalia: there is no USB drive island (drives still mount from Dolphin) and no "Restart to UEFI" in the power menu.

## Three compositors

The compositor is the part that draws and arranges your windows. ZeXOS sets up three, and you pick one on the login screen (the session menu next to the password box): **niri** (the default), [**Mango**](https://github.com/mangowm/mango) and [**Hyprland**](https://hypr.land).

Mango is set up to feel like niri: windows sit side by side in a row that scrolls sideways, each one half the screen wide at first, with the same gaps, borders, round corners, blur and keys. Both shells work in it, `Mod+Shift+D` switches between them, and window colours follow the wallpaper the same way. Mango's config is in `~/.config/mango`.

Mango and Hyprland have no overview like niri's, so ZeXOS adds its own, [mango-overview](https://github.com/zefuros1991/mango-overview). `Mod+O`, a quick double tap of `Mod`, or four fingers up opens it: every workspace as a card with live window previews. Drag a window onto another workspace to move it, swipe three fingers up or down to go through the workspaces and sideways to go through the windows (one swipe can cross several), and press `Enter` or click to go there. Four fingers down or `Esc` closes it. Mango's own built-in overview is still on `Mod+Shift+O`.

Some niri things Mango doesn't have, so in Mango:

- Workspaces are Mango's "tags" 1 to 9. Each screen has its own; `Mod+Tab` goes back to the last one.
- There is no jump to the first or last window (`Mod+Home`/`Mod+End`), and no keys to make a window taller or shorter.
- `Mod+Minus` and `Mod+Equal` step through set widths (a quarter, a third, a half, two thirds, three quarters, full) instead of 10% at a time.
- `Mod+Shift+Escape` shows the same cheat sheet as `Mod+F1` (niri's own hotkey overlay doesn't exist there). Under Noctalia it is a simple searchable list.
- Screenshots use `zexos-screenshot` (grim and slurp) and are saved and copied the same way.

Hyprland is the odd one out on purpose: it **tiles** instead of scrolling. Each new window takes half of the one you're in, side by side on wide windows and one above the other on tall ones, like folding a sheet of paper in half and then in half again. Nothing is ever off screen. `Mod+J` flips a split between side by side and one above the other. Everything else matches niri: the gaps, borders, round corners, blur, keys and both shells, and window colours follow the wallpaper. Hyprland's config is in `~/.config/hypr`, written in Lua (`hyprland.lua` plus the files in `cfg/`).

What is different in Hyprland:

- There is no jump to the first or last window (`Mod+Home`/`Mod+End`).
- `Mod+Minus`/`Mod+Equal` move the line between two windows left or right by 100 pixels (with Shift, up or down): one window grows and its neighbour shrinks.
- `Mod+Shift+Escape` shows the same cheat sheet as `Mod+F1`.

---

[Back to the README](../README.md) · [All docs](README.md)
