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
  in the new `dms` stow package.

### Changed

- niri starts the desktop shell through `zshell start` instead of starting
  Noctalia directly.
- niri window colours and kitty colours follow whichever shell is running.
- The roller wallpaper picker sets the wallpaper through `zshell`.

## [1.0.0] - 2026-09-30

First release: niri, patched Noctalia v5, roller, SDDM with Pixie, colours
from the wallpaper, and one installer for CachyOS, Arch Linux, EndeavourOS
and other Arch-based distros (any desktop already installed).

[Unreleased]: https://github.com/zefuros1991/ZeXOS/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/zefuros1991/ZeXOS/releases/tag/v1.0.0
