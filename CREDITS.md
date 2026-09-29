# Credits

ZeXOS is my own setup: the config files, the install scripts, a couple of
small patches, and the wallpapers (drawn from scratch by
`wallpapers/make-wallpapers.py`, no photos or outside art). Everything it runs on was made by other people, and it would
not exist without them. Thank you.

## Built on

| Project | What it does in ZeXOS |
|---|---|
| [CachyOS](https://cachyos.org) and [Arch Linux](https://archlinux.org) | The Linux system underneath, and the repos almost every package comes from |
| [niri](https://github.com/YaLTeR/niri) by Ivan Molodetskikh | The window manager: scrolling columns of windows |
| [Noctalia](https://github.com/noctalia-dev/noctalia) | The shell: top bar, launcher, notifications, lock screen, colours from the wallpaper |
| [roller](https://github.com/zyrophix/roller) by zyrophix | The wallpaper picker (Mod+W) |
| [kitty](https://github.com/kovidgoyal/kitty) | Terminal |
| [fuzzel](https://codeberg.org/dnkl/fuzzel) | Small app launcher and picker menus |
| [Dolphin](https://apps.kde.org/dolphin/) | File manager |
| [Shelly](https://github.com/Seafoam-Labs/Shelly-ALPM) | App store for installing and updating software (Mod+M, CachyOS) |
| [Discover](https://apps.kde.org/discover/) | The same job as Shelly on other Arch-based distros |
| [Pixie](https://github.com/xCaptaiN09/pixie-sddm) by xCaptaiN09 | The login screen theme |
| [qt6ct](https://www.opencode.net/trialuser/qt6ct) by Ilya Kotov | Lets Qt and KDE apps follow the dark theme |
| [Bibata](https://github.com/ful1e5/Bibata_Cursor) by ful1e5 | Mouse pointer |
| [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) | Icon theme; its folder icons are recoloured to follow the wallpaper |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info shown in the terminal |
| [GNU Stow](https://www.gnu.org/software/stow/) | Links the config files from this repo into your home folder |
| [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) | Makes older GTK apps match the modern GNOME look |

The installer downloads all of these from their official sources: the
CachyOS/Arch repos, or the project's own GitHub for the few that aren't in
the repos (checked against a fixed checksum). ZeXOS does not use the AUR.
None of their code is copied into this repo, and each one keeps its own
license.

## Files here that contain other people's code

These are the only files in this repo with someone else's code inside them.
They keep their original license (MIT, except the qt6ct patches, which follow
qt6ct's BSD-2-Clause license, and the recipes taken from Arch and the AUR,
which follow those projects' 0BSD packaging license).

| File | What it is | Original project |
|---|---|---|
| `packaging/noctalia-zexos/zexos.patch` | ZeXOS changes to Noctalia | [Noctalia](https://github.com/noctalia-dev/noctalia), noctalia-dev |
| `packaging/roller/zexos-wheel-and-size.patch` | ZeXOS changes to roller | [roller](https://github.com/zyrophix/roller), zyrophix |
| `packaging/qt6ct-kde/zexos-live-colors.patch` | ZeXOS change to qt6ct so open apps pick up new colours | [qt6ct](https://www.opencode.net/trialuser/qt6ct), Ilya Kotov |
| `packaging/qt6ct-kde/qt6ct-shenanigans.patch` | Lets qt6ct pass colours to KDE apps (copied unchanged) | [qt6ct-kde](https://aur.archlinux.org/packages/qt6ct-kde) recipe by Antonio Rojas, for [qt6ct](https://www.opencode.net/trialuser/qt6ct) by Ilya Kotov |

The patches were written for ZeXOS, but each one also quotes a few lines of
the original code so it knows where to apply. While building, the PKGBUILDs
download the original source from its authors and apply the patch to it.

Please feel free to read the patches, PKGBUILDs and scripts before you run
anything. They are short and plain text on purpose. Checking code before you
run it is a good habit with any project, this one included.
