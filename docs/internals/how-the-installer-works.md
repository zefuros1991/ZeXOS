# How the installer works

For contributors. A map of what `install.sh` does. You don't need this page to install ZeXOS.

## The big picture

`install.sh` first checks which distro you're on and stops if it's one ZeXOS can't support. Then it runs four scripts from `scripts/`, in order:

| # | Script | Job |
|---|---|---|
| 1 | `bootstrap.sh` | Gets the system ready |
| 2 | `packages.sh` | Installs the desktop and apps |
| 3 | `stow.sh` | Links the config into your home folder |
| 4 | `finaltouches.sh` | Wallpapers and login-screen sync |

Each step keeps a log in `~/.dotfiles`. Logs are gitignored.

## 1. Bootstrap (`bootstrap.sh`)

- Turns on the `multilib` repo if it's off
- Updates the system
- Installs the basics: `git`, `curl`, `stow`, `base-devel`, `flatpak`
- Adds Flathub
- Clones this repo to `~/.dotfiles`

## 2. Packages (`packages.sh`)

Installs, skipping anything already there:

- **The desktop:** niri, Mango, Hyprland, Noctalia (and its patched build), DankMaterialShell, roller, fuzzel, kitty
- **ZeXOS's own few packages**, ready-made or built, as chosen ([compare the two](../install-options.md#ready-made-or-build-it-yourself))
- **The basics a non-niri install may lack:** portals, keyring, fonts, sound, network, Bluetooth and power services
- **Everyday apps, fonts and themes**
- **SDDM with Pixie** (the login screen)

The installer makes a list of every package first, then installs them all in one pacman run. If that run fails, it installs them one at a time, so the log still names the package that caused it.

**Distro steps.** The installer reads `/etc/os-release` (`scripts/lib-distro.sh`), then runs `scripts/distro/cachyos.sh` or `scripts/distro/arch.sh`. If you added the CachyOS repos to Arch, the real CachyOS package is used.

**Login screen.** If another one is in use (GDM, Plasma Login, ...), it switches to SDDM only after checking SDDM and Pixie are installed and ready.

**Qt updates.** A pacman hook rebuilds the patched `qt6ct-kde` after every Qt update. That patch lets open apps like Dolphin change colour with the wallpaper, and a new Qt can break it. To see how the last rebuild went:

```bash
journalctl -u zexos-qt6ct-rebuild
```

## 3. Stow (`stow.sh`)

Links every config package under `stow/` into your home folder with [GNU Stow](https://www.gnu.org/software/stow/). Any existing file in the way is first backed up to `backup/stow-<timestamp>/`.

The packages are listed in [Customizing ZeXOS](../customizing.md#config-packages).

## 4. Final touches (`finaltouches.sh`)

- Copies the wallpapers to `~/Pictures/Wallpapers`
- Sets up the login-screen wallpaper sync

## Logs

| Log | From |
|---|---|
| `install.log` | The whole run |
| `bootstrap.log` | Step 1 |
| `packages.log` | Step 2 |
| `stow.log` | Step 3 |
| `finaltouches.log` | Step 4 |

All are in `~/.dotfiles`.

---

[Back to internals](README.md)
