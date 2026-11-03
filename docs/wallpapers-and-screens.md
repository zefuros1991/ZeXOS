# Wallpapers and screens

## Wallpapers

ZeXOS comes with 16 wallpapers of its own, in 5 styles and several colours each, plus 9 animated ones. The installer copies them to `~/Pictures/Wallpapers`, and you start on `zexos-aurora`. The login screen starts with it too.

<a href="https://zefuros1991.github.io/ZeXOS/?from=readme#16"><img src="screenshots/wallpapers.webp" alt="The ZeXOS wallpapers"></a>

Press `Mod+W` to pick another one. Put your own pictures in `~/Pictures/Wallpapers` too: Noctalia and roller read from there, and the colour theme follows whichever one is active.

All of them are drawn by `wallpapers/make-wallpapers.py`, with no photos or downloads. To make them in another size, run `python wallpapers/make-wallpapers.py 2560 1440`.

## Animated wallpapers

Nine of the wallpapers also come as 12-second looping videos, covering every style and colour family. They go in `~/Pictures/Wallpapers/Animated`. None is switched on by default, because a looping 4K video puts a small, constant load on the machine.

| Video | What moves |
|---|---|
| `zexos-aurora`, `-ocean`, `-mono` | the three light ribbons ripple, sway and drift |
| `zexos-topo-energy`, `zexos-topo-ember` | energy runs along the contour lines |
| `zexos-mark-ember`, `-light` | the logo's glow breathes and a sheen passes over it; the logo stays still |
| `zexos-bars` | the bars rise and fall gently, like a slow equaliser |
| `zexos-dots-forest` | a wave of light passes through the dots, and some twinkle |

roller shows the pictures and the videos as two groups: `Mod+W` opens it on the pictures, `Mod+Shift+W` on the videos, and `Tab` switches between them. Video cards carry a ▶ badge. Picking a video plays it with Noctalia's Video Wallpaper plugin (ZeXOS ships a copy of it with one extra command, see `ZEXOS.md` in `~/.local/share/noctalia/plugins/mpvpaper`), and its first frame becomes the picture the colour theme follows. Picking a picture stops the video. Under DMS, which can't play videos, you get the first frame as a still.

The `wallpapers/make-*-video.py` scripts draw them (they need `python-numpy`, `python-pillow` and `ffmpeg`).

## Screens

niri detects your screens by itself. To set resolution, scale or position, run `niri msg outputs` and add blocks to `stow/niri/.config/niri/monitors.kdl` (there's a commented example in the file). For Mango, run `mmsg get all-monitors` and add `monitor_rule=` lines to `stow/mango/.config/mango/monitors.conf`. For Hyprland, run `hyprctl monitors` and add `hl.monitor` lines to `stow/hyprland/.config/hypr/monitors.lua`.

---

[Back to the README](../README.md) · [All docs](README.md)
