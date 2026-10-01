# Changelog

All notable changes to ZeXOS are listed here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

Planned as 1.1.0.

### Added

- Animated versions of 8 more wallpapers, 9 in all, covering every style
  and colour family: aurora (violet, ocean, mono), topo (energy, ember),
  mark (ember, light), bars and dots (forest). Each is a 12-second 4K loop
  whose first frame is the still picture. They live in
  `~/Pictures/Wallpapers/Animated` (it was `~/Videos/Wallpapers`).
- roller shows pictures and videos as two groups. `Mod+Shift+W` opens it
  on the videos, `Tab` switches groups, and video cards carry a ▶ badge
  (`packaging/roller/zexos-video-groups.patch`).
- A ZeXOS copy of Noctalia's Video Wallpaper plugin with one more command,
  `set`, so the picker can start a video.
- Hyprland and Mango dim the windows you're not using, like niri does.
  Hyprland also gets niri's gradient border in the wallpaper colours under
  Noctalia (`templates/hypr-border.lua`). Mango can only draw a border in
  one colour, so it keeps Noctalia's.

- DankMaterialShell (DMS) as a second desktop shell, installed next to
  Noctalia (`dms-shell`, `dms-shell-niri`, `matugen`). Noctalia stays the
  default. See [Two desktop shells](README.md#two-desktop-shells).
- `zshell`, one helper that every shell keybind calls. It passes the action
  to the running shell, so the keys work the same in both.
- `Mod+Shift+D` opens a menu to switch shells: two big choices, each with
  the shell's logo and its name in Nunito ExtraBold (`ttf-nunito`). It is a
  small Quickshell window (`~/.config/quickshell/zexos-switcher`) with no
  search box, so a stray key press can't hide the choices. Arrows, Tab,
  j/k or W/S move, Enter picks, 1/2 pick straight away, Esc or a click outside
  closes, and the same key closes it again. The choice is saved per user in
  `~/.config/zexos/shell`.
- A ZeXOS look for DMS on its first start (bar, fonts, wallpaper), in the
  new `dms` stow package. The bar uses DMS's Dank Island with three groups,
  like Noctalia's islands: CPU use and updates on the left; the island
  (workspaces, clock, music) in the middle; tray, quick settings (network,
  Bluetooth, sound, brightness), notifications, battery and the shell
  switcher on the right. Each side shares one background (DMS's own
  satellite background setting, no patch), and CPU is one button, like
  Noctalia.
- A shell switcher button on the bar of both shells. It opens the same
  menu as `Mod+Shift+D`.
- `zexos-dms-sync`, a small watcher (`zexos-dms-sync.path`) that does for
  DMS what Noctalia does by itself after a wallpaper change: Dolphin and
  other KDE apps, GTK apps, fuzzel menus and btop take the new colours,
  the login screen gets the new wallpaper, and a very bright wallpaper
  turns on light mode.
- `zshell relink` and `zexos-kde-colors`, which the watcher uses.
- Mango (`mangowm`) as a second compositor, picked on the login screen.
  Its config (new `mango` stow package) copies the niri one: the
  scrolling layout, gaps, borders, round corners, blur, window rules and
  the same keys. Both shells work in it, with the shell switcher, and
  window colours follow the wallpaper. See
  [Three compositors](README.md#three-compositors).
- Hyprland as a third compositor, picked on the login screen
  (`hyprland`, `xdg-desktop-portal-hyprland`, `dms-shell-hyprland`). Its
  config (new `hyprland` stow package, written in Hyprland's Lua format)
  tiles windows instead of scrolling them (the "dwindle" layout), and
  otherwise copies niri: gaps, borders, round corners, blur, window rules
  and the same keys. Both shells work in it, with the shell switcher, and
  window colours follow the wallpaper.
- `zexos-screenshot` takes area, screen and window screenshots on Mango
  and Hyprland.
- Mango: workspaces work like niri's. They are stacked top to bottom and
  slide up and down, with no empty ones in between (`tag_gather`).
  Noctalia's bar shows only the workspaces in use, the top-left corner
  opens the overview, and Noctalia's pop-ups get the same frosted-glass
  blur as on niri.
- Mango: `Alt+Tab` opens the carousel to go through every window. Let go
  of Alt to jump to the chosen window; `Shift` goes backwards.
- On niri, the overview (`Mod+O`) shows your wallpaper behind it under
  DMS too, not plain grey (DMS's own `place-within-backdrop` rule).

### Changed

- niri: windows you're not using are now dimmed darker instead of just
  faded, and every app dims by the same amount (kitty, which is already
  see-through, gets a lighter setting so it matches). The border is drawn
  as a frame round the edge only, so it no longer shows through see-through
  windows as a grey haze.
- niri with Noctalia: the focused window's border is a gradient in the
  wallpaper's colours (Noctalia template `templates/niri-border.kdl`,
  included through `shell-colors.kdl` so DMS keeps its own colours).
- niri starts the desktop shell through `zshell start` instead of starting
  Noctalia directly. Mango and Hyprland do the same.
- niri window colours and kitty colours follow whichever shell is running.
- The roller wallpaper picker sets the wallpaper through `zshell`. After a
  shell switch, the login screen keeps the last wallpaper until the next
  wallpaper change.
- Qt apps read `ZeXOS.colors`, fuzzel reads `themes/shell` and GTK reads
  `shell.css`. zshell points each at the colours of the shell in use.
- DMS bar: the middle island opens on click instead of on hover, and
  touches the top edge like the side groups. Existing DMS setups are
  moved over too.
- DMS app launcher always opens on the Apps tab.
- The wallpaper picker closes after you pick, so you see the change.
- Shell switcher menu: bigger, no search box, Nunito font, shell names in
  the theme colour and "IN USE" always in orange.
- The installer updates the system before installing git, so an older
  Arch install doesn't fail.
- Sound, music and brightness keys have readable names on the shortcut
  cheat sheet. Noctalia's cheat sheet shows them after the next login.

### Fixed

- niri's gradient border never showed: its template path in
  `noctalia.toml` was relative, and Noctalia only takes full paths.
- After using Mango, the shortcut list (`Mod+F1`) on niri showed Mango's
  shortcuts. An empty Mango variable left from that session made
  Noctalia think it was still in Mango; `zshell start` now drops it.

- Picking a picture in roller while a video wallpaper played changed the
  colours but left the video on screen. Pictures now stop the video, and
  picking a video plays it. Random wallpaper (`Mod+Ctrl+W`) stops it too.

- Switching to or from a video wallpaper showed a grey screen for about a
  second instead of the usual wallpaper transition. Noctalia now runs its
  normal transition in every case, and the video only takes over once its
  first frame is on screen.

- Under DMS, the shell switcher and other fuzzel menus now take the
  wallpaper colours. Noctalia's fuzzel hook had pointed `fuzzel.ini` at
  Noctalia's colours for good, so they stayed on the last Noctalia
  colours.
- Under DMS, kitty now takes the wallpaper colours. It never loaded them
  before, and windows that are already open now update too.
- Qt and KDE apps that are already open (like Dolphin) now change colour
  with the wallpaper or a shell switch, on every compositor and with both
  shells. qt6ct only re-reads colours when its own folder changes, so the
  new `zexos-qt-refresh` touches that folder after each colour update.
- Under DMS, a wallpaper change no longer misses the new colours now and
  then. DMS saves the colours a moment after the wallpaper, and systemd
  drops changes that arrive while the sync is still running, so
  `zexos-dms-sync` keeps checking for a few more seconds.
- Switching shells could leave a frozen Noctalia behind (upstream
  [noctalia#4652](https://github.com/noctalia-dev/noctalia/issues/4652)).
  Its wallpaper covered DMS's, so a DMS wallpaper change did nothing, and
  switching back never started Noctalia. `zshell` now force-quits a shell
  that hasn't closed after 3 seconds.
- New kitty windows no longer open maximized on top of the others.
- fastfetch in kitty no longer breaks up when tiling resizes the window,
  in fish and in bash.
- A black desktop on plain Arch: `~/.local/bin` is now on everyone's
  PATH at login.
- On plain Arch with no real browser, Firefox is installed so `Mod+B`
  works.
- `Mod+B` opens a real browser when DMS is installed. DMS's link chooser
  (`dms-open`) says it opens web links, so it was picked by mistake.

### Known gaps in DMS

- No USB drive island: DMS has no widget for it (Noctalia uses the
  udiskie plugin). Drives still mount from Dolphin.
- No "Restart to UEFI" in the DMS power menu.
- If you already used DMS before, your own DMS bar is kept; the ZeXOS bar
  only comes with a fresh DMS setup.

### Known gaps in Mango

- No keys to jump to the first or last window, or to make a window taller
  or shorter. Mango has nothing for these.
- `Mod+Minus`/`Mod+Equal` step through set widths instead of 10% at a
  time.
- Noctalia's cheat sheet doesn't know Mango, so under Noctalia `Mod+F1`
  shows a simple searchable list instead.

### Known gaps in Hyprland

- It tiles instead of scrolling, so there is no overview (`Mod+O`) and
  no keys to jump to the first or last window.
- `Mod+Minus`/`Mod+Equal` move the line between two windows by 100
  pixels instead of changing one window's width by 10%, so on the
  right-hand window `Mod+Equal` makes it smaller.
- Once in testing, Hyprland 0.56.2 closed the whole session during a DMS
  wallpaper change (DMS rewrites Hyprland's colour file, which makes
  Hyprland reload). It left no crash report and did not happen again in
  17 more tries. Upstream reports crashes on repeated reloads in 0.55/0.56.

## [1.0.0] - 2026-09-30

First release: niri, patched Noctalia v5, roller, SDDM with Pixie, colours
from the wallpaper, and one installer for CachyOS, Arch Linux, EndeavourOS
and other Arch-based distros (any desktop already installed).

[Unreleased]: https://github.com/zefuros1991/ZeXOS/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/zefuros1991/ZeXOS/releases/tag/v1.0.0
