# ZeXOS copy of Noctalia's official "Video Wallpaper" plugin (noctalia/mpvpaper 1.2.0)

Noctalia loads a plugin from `~/.local/share/noctalia/plugins/<name>/` before
the official one with the same id, so this copy replaces it.

The only change is in `mpvpaper_service.luau`: one more IPC event, `set`.

    noctalia msg plugin noctalia/mpvpaper:service all set /path/to/video.mp4

It plays that video on every screen. The official plugin can only start a
video from its own panel, so the wallpaper picker (roller, Mod+W) had no way
to start or stop one. `zshell wallpaper-set` (which roller calls) now sends `set` for a video
and `clear-all` for a picture.

When the official plugin updates, copy the new files over this folder and add
the `set` branch to `onIpc` again (search for "ZeXOS addition").
