# Install options

Extra choices for the install script, the way to add ZeXOS to a system you already have. None are needed for a normal install. On the ISO you make these choices in the installer instead.

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
| What happens | Downloads packages already built for you | Builds each one on your computer from source |
| Time | About 2½ minutes for the whole install on a fresh Arch | Several minutes more. Noctalia is the slow one. |
| Updates | `pacman -Syu` keeps them updated | Rebuilt by you |
| Best for | Almost everyone | People who want to build from source |

Both give you the same packages. To skip the question, use `ZEXOS_PACKAGES=prebuilt` or `ZEXOS_PACKAGES=source`.

**If a ready-made package can't be used** (no download, a damaged download, or a version that doesn't match your system), the installer builds that one on your computer instead. You don't have to do anything.

## What differs on CachyOS and other distros

Almost everything comes from Arch's official repos, which all supported distros share. Only one thing is CachyOS-only:

| On CachyOS | Elsewhere |
|---|---|
| Shelly (app store, `Mod+M`) | KDE Discover |

The installer works out which one you have by itself. If you added the CachyOS repos to your Arch install, you get the CachyOS version.

---

[Back to Installing ZeXOS](install.md) · [All docs](README.md)
