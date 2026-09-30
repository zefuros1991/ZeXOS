# Changelog

All notable changes to ZeXOS are listed here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and version numbers follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

Planned as 1.1.0.

### Added

- DankMaterialShell (DMS) as a second desktop shell, installed next to
  Noctalia (`dms-shell`, `dms-shell-niri`, `matugen`). Noctalia stays the
  default. See [Two desktop shells](README.md#two-desktop-shells).
- `zshell`, one helper that every shell keybind calls. It passes the action
  to the running shell, so the keys work the same in both.
- `Mod+Shift+D` opens a menu to switch shells: two big choices, each with
  the shell's logo and its name in Nunito ExtraBold (`ttf-nunito`). It is a
  small Quickshell window (`~/.config/quickshell/zexos-switcher`) with no
  search box, so a stray key press can't hide the choices. Arrows, Tab or
  j/k move, Enter picks, 1/2 pick straight away, Esc or a click outside
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

### Changed

- niri starts the desktop shell through `zshell start` instead of starting
  Noctalia directly. Mango and Hyprland do the same.
- niri window colours and kitty colours follow whichever shell is running.
- The roller wallpaper picker sets the wallpaper through `zshell`. After a
  shell switch, the login screen keeps the last wallpaper until the next
  wallpaper change.
- Qt apps read `ZeXOS.colors`, fuzzel reads `themes/shell` and GTK reads
  `shell.css`. zshell points each at the colours of the shell in use.
- Sound, music and brightness keys have readable names on the shortcut
  cheat sheet. Noctalia's cheat sheet shows them after the next login.

### Fixed

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
- `Mod+B` opens a real browser when DMS is installed. DMS's link chooser
  (`dms-open`) says it opens web links, so it was picked by mistake.

### Known gaps in DMS

- DMS can't group several bar items into one island like Noctalia, so
  each item has its own pill. (DMS's own "island" mode is a different
  thing, a single pop-up pill that hides the workspaces.)
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
