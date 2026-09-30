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
- `Mod+Shift+D` opens a menu to switch shells. The choice is saved per user
  in `~/.config/zexos/shell`.
- A ZeXOS look for DMS on its first start (island bar, fonts, wallpaper),
  in the new `dms` stow package. The bar has the same islands in the same
  order as Noctalia's: system use and updates on the left; workspaces,
  clock and music in the middle; tray, quick settings (network, Bluetooth,
  sound, brightness), notifications, battery and the shell switcher on
  the right.
- A shell switcher button on the bar of both shells. It opens the same
  menu as `Mod+Shift+D`.
- `zexos-dms-sync`, a small watcher (`zexos-dms-sync.path`) that does for
  DMS what Noctalia does by itself after a wallpaper change: Dolphin and
  other KDE apps, GTK apps, fuzzel menus and btop take the new colours,
  the login screen gets the new wallpaper, and a very bright wallpaper
  turns on light mode.
- `zshell relink` and `zexos-kde-colors`, which the watcher uses.

### Changed

- niri starts the desktop shell through `zshell start` instead of starting
  Noctalia directly.
- niri window colours and kitty colours follow whichever shell is running.
- The roller wallpaper picker sets the wallpaper through `zshell`. After a
  shell switch, the login screen keeps the last wallpaper until the next
  wallpaper change.
- Qt apps read `ZeXOS.colors`, fuzzel reads `themes/shell` and GTK reads
  `shell.css`. zshell points each at the colours of the shell in use.
- Sound, music and brightness keys have readable names on the shortcut
  cheat sheet. Noctalia's cheat sheet shows them after the next login.

### Known gaps in DMS

- No USB drive island: DMS has no widget for it (Noctalia uses the
  udiskie plugin). Drives still mount from Dolphin.
- No "Restart to UEFI" in the DMS power menu.
- If you already used DMS before, your own DMS bar is kept; the ZeXOS bar
  only comes with a fresh DMS setup.

## [1.0.0] - 2026-09-30

First release: niri, patched Noctalia v5, roller, SDDM with Pixie, colours
from the wallpaper, and one installer for CachyOS, Arch Linux, EndeavourOS
and other Arch-based distros (any desktop already installed).

[Unreleased]: https://github.com/zefuros1991/ZeXOS/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/zefuros1991/ZeXOS/releases/tag/v1.0.0
