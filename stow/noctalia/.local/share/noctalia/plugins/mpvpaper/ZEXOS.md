# ZeXOS copy of Noctalia's official "Video Wallpaper" plugin (noctalia/mpvpaper 1.2.0)

Noctalia loads a plugin from `~/.local/share/noctalia/plugins/<name>/` before
the official one with the same id, so this copy replaces it.

All changes are in `mpvpaper_service.luau`; search for "ZeXOS".

1. Two more IPC events, so the wallpaper picker (roller, Mod+W) can start and
   stop videos. The official plugin can only do that from its own panel.

       noctalia msg plugin noctalia/mpvpaper:service all set "<video><TAB><poster>"
       noctalia msg plugin noctalia/mpvpaper:service all picture /path/to/image.jpg

   `set` moves to the poster (the video's first frame) with Noctalia's usual
   wallpaper transition, then plays the video on every screen on top of it.
   The poster part is optional. `picture` stops any video and moves to the
   picture with the transition. `zshell wallpaper-set` (which roller calls) sends these.

2. No grey flash between wallpapers. The official plugin stops a video while
   Noctalia's own wallpaper is still switched off, and hides Noctalia's
   wallpaper a fixed 0.8 s after starting a video, often before the video has
   drawn anything. Both left the compositor's grey background on screen for a
   moment. This copy shows the video's current frame in Noctalia before it
   stops the video (`set`, `picture` and `clear-all`), and asks mpv over its
   socket until the new video has shown a few frames before hiding Noctalia's
   wallpaper (see "SMOOTH SWITCHES").

When the official plugin updates, copy the new files over this folder and put
these changes back.
