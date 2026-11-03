# Install options

Extra choices for the install script. None are needed for a normal install.

Put any of these in front of the install command, for example `ZEXOS_SHELLS=noctalia bash install.sh`.

| Variable | Values | Default | What it does |
|---|---|---|---|
| `ZEXOS_COMPOSITORS` | `niri`, `hyprland`, `mango` (space-separated) | all three | Which compositors to install |
| `ZEXOS_SHELLS` | `noctalia`, `dms` (space-separated) | both | Which desktop shells to install |
| `ZEXOS_PACKAGES` | `prebuilt`, `source` | asks you | How to get ZeXOS's own packages |
| `ZEXOS_DISTRO` | `arch`, `cachyos` | detected | Which distro steps to run |

Your answers are remembered, so updates keep them.

## Install only some compositors or shells

```bash
ZEXOS_COMPOSITORS="niri mango" ZEXOS_SHELLS=noctalia bash install.sh
```

With one shell installed, the shell switcher is left out.

## Ready-made or build it yourself

A few ZeXOS apps aren't in the Arch or CachyOS repos: the patched Noctalia, the Pixie login theme, the Bibata pointer, roller, qt6ct-kde and (outside CachyOS) mpvpaper. Right after the password, the installer asks how to get them.

| | 1. Ready-made (default) | 2. Build here |
|---|---|---|
| What happens | Downloads ZeXOS's own package repo | Builds each one on your computer from the recipes in `packaging/` |
| Time | About 2½ minutes for the whole install on a fresh Arch | Several minutes more. Noctalia is the slow one. |
| Updates | `pacman -Syu` keeps them updated | Rebuilt by you |
| Best for | Almost everyone | People who want to build from source |

Both give you the same packages. To skip the question, use `ZEXOS_PACKAGES=prebuilt` or `ZEXOS_PACKAGES=source`.

**If a ready-made package can't be used**, that one is built here instead. This happens when there is no download, the checksum is wrong, or `qt6ct-kde` was made for a different Qt than yours.

**How ready-made works.** The [`prebuilt` release](https://github.com/zefuros1991/ZeXOS/releases/tag/prebuilt) on GitHub is added to `/etc/pacman.conf` as a package repo, checked against the checksum in `packaging/prebuilt.list`. The packages install with everything else in one pacman run. If the repo can't be reached or fails its check, each package is fetched on its own: the AUR first (`<name>-bin`, only if you have `yay` or `paru`), then the GitHub release, each checksum-checked.

The packages are built in a clean Arch Linux container by `scripts/make-prebuilt.sh`, the same way Arch builds its own ([clean chroot builds](https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot)).

## What differs on CachyOS and other distros

Almost everything comes from Arch's official repos, which all supported distros share. Only one thing is CachyOS-only:

| On CachyOS | Elsewhere |
|---|---|
| Shelly (app store, `Mod+M`) | KDE Discover |

The installer tells them apart by reading `/etc/os-release` (`scripts/lib-distro.sh`), then runs `scripts/distro/cachyos.sh` or `scripts/distro/arch.sh`. If you added the CachyOS repos to your Arch install, the real CachyOS package is used.

---

[Back to Installing ZeXOS](install.md) · [All docs](README.md)
