# Packages and patches

For contributors. How ZeXOS's own packages are built and served, and the patches on top of other projects.

## Which packages are ZeXOS's own

A few pieces aren't in the Arch or CachyOS repos: the patched Noctalia, the Pixie login theme, the Bibata pointer, roller, qt6ct-kde and (outside CachyOS) mpvpaper. Recipes are in `packaging/`. Users get them [ready-made or built on their computer](../install-options.md#ready-made-or-build-it-yourself).

## How ready-made works

1. The [`prebuilt` release](https://github.com/zefuros1991/ZeXOS/releases/tag/prebuilt) on GitHub is added to `/etc/pacman.conf` as a package repo, checked against the checksum in `packaging/prebuilt.list`.
2. The packages install with everything else in one pacman run.
3. If the repo can't be reached or fails its check, each package is fetched on its own: the AUR first (`<name>-bin`, only if the user has `yay` or `paru`; ZeXOS never installs an AUR helper), then the GitHub release. Each download is checksum-checked.
4. If a ready-made package can't be used (no download, wrong checksum, or `qt6ct-kde` made for a different Qt than the system's), that one is built on the computer instead.

The packages are built in a clean Arch Linux container by `scripts/make-prebuilt.sh`, the same way Arch builds its own ([clean chroot builds](https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot)). Run it again after any PKGBUILD bump, and redo the Qt prebuilts per Qt bump.

## The patches

Each patch was written for ZeXOS, but also quotes a few lines of the original code so it knows where to apply. While building, the PKGBUILDs download the original source from its authors and apply the patch to it. The projects and licenses are listed in [CREDITS](../../CREDITS.md#files-with-other-peoples-code).

| Patch | What it does |
|---|---|
| `packaging/noctalia-zexos/zexos.patch` | Attaches the three bar "islands" to the top edge and adds a launcher-only size option |
| `packaging/roller/zexos-wheel-and-size.patch` | ZeXOS changes to roller |
| `packaging/qt6ct-kde/zexos-live-colors.patch` | Lets already-open apps pick up new colours |
| `packaging/qt6ct-kde/qt6ct-shenanigans.patch` | Lets qt6ct pass colours to KDE apps (copied unchanged) |

## The login theme avatars

`packaging/pixie-sddm-zexos/make-avatar.py` draws the six avatars. The login screen shows the ZeXOS logo as its round picture, in the current wallpaper's colours, and both change with every wallpaper change and shell switch.

---

[Back to internals](README.md)
