# Desktop and wallpapers

For contributors. How the shell switching works under the hood, and the scripts that draw the wallpapers.

## The `zshell` helper

The keybinds call a small helper, `zshell`, instead of a shell directly. It sends each action (launcher, lock, volume, wallpaper, ...) to whichever shell is running. That is why the keys are the same in both shells.

```bash
zshell --help
zshell switch dms
zshell switch noctalia
```

## How DankMaterialShell gets its look

The first time DMS starts, it gets a ZeXOS look copied from `stow/dms/.local/share/zexos/dms/`. It is a copy, so changes made in DMS's own settings are kept.

- The same bar items as Noctalia, in the same order, in three groups: CPU use and updates on the left; DMS's Dank Island in the middle (workspaces, clock, music); tray, quick settings, notifications, battery and the shell switcher on the right
- Each side shares one background, set with DMS's own island settings (no patch)
- The same font sizes and the ZeXOS wallpaper

A small watcher, `zexos-dms-sync`, does the colour parts DMS doesn't:

```bash
systemctl --user status zexos-dms-sync.path
```

## Wallpaper scripts

All the wallpapers are drawn by code, with no photos or downloads.

```bash
python wallpapers/make-wallpapers.py 2560 1440   # pictures, in another size
```

The `wallpapers/make-*-video.py` scripts draw the animated ones. They need `python-numpy`, `python-pillow` and `ffmpeg`.

## Video wallpaper plugin

Picking a video plays it with Noctalia's Video Wallpaper plugin. ZeXOS ships a copy with one extra command. See `ZEXOS.md` in `~/.local/share/noctalia/plugins/mpvpaper`.

---

[Back to internals](README.md)
