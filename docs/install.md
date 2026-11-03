# Installing ZeXOS

ZeXOS is made for Arch-based distros that use Arch's own repos, so it should run on most of them. It has been tested on **CachyOS**, **Arch Linux** and **EndeavourOS**; other Arch-based distros are likely to work too, but haven't been tried yet. It doesn't matter which desktop was picked during the distro's install (KDE, GNOME, niri or none): ZeXOS adds what's missing, and the old desktop stays available in the login screen's session list.

Two Arch-based distros are not supported: Manjaro (it has its own, delayed repos) and Artix (it doesn't use systemd). On those the installer stops early and explains why.

Almost everything comes from Arch's official repos, which all of the supported distros share. Only one thing is CachyOS-only, and on other distros ZeXOS uses a stand-in:

| On CachyOS | Elsewhere |
|---|---|
| Shelly (app store, `Mod+M`) | KDE Discover |

The installer tells them apart by reading `/etc/os-release` (see `scripts/lib-distro.sh`), then runs `scripts/distro/cachyos.sh` or `scripts/distro/arch.sh`. Each step also asks pacman first, so if you added the CachyOS repos to your Arch install, the real CachyOS package is used. To pick by hand, put `ZEXOS_DISTRO=arch` (or `cachyos`) in front of the install command.

```bash
curl -fsSL https://raw.githubusercontent.com/zefuros1991/ZeXOS/main/install.sh -o /tmp/zexos-install.sh; bash /tmp/zexos-install.sh; rm -f /tmp/zexos-install.sh
```

This downloads the installer, runs it, then deletes it. It works the same in fish, bash and zsh. Avoid `curl … | bash`: the installer asks for your sudo password, and piping the script in takes over the input that prompt needs.

If you already cloned the repo to `~/.dotfiles`:

```bash
cd ~/.dotfiles
./install.sh
```

<p align="center"><img src="screenshots/install.gif" alt="The ZeXOS installer starting in a terminal: the gradient ZeXOS logo animates while it waits for the sudo password" width="640"></p>

Run it as your normal user, not root. You need an account that can use `sudo` and a network connection. The installer adds `git` if it's missing, and the bootstrap step installs everything else, including `stow`.

## Fast install or build it yourself

A few ZeXOS apps aren't in the Arch or CachyOS repos: the patched Noctalia, the Pixie login theme, the Bibata pointer, roller, qt6ct-kde and (outside CachyOS) mpvpaper. Right after the password, the installer asks how to get them:

| Choice | What happens | Time |
|---|---|---|
| **1. Ready-made** (default) | Adds ZeXOS's own package repo (the [`prebuilt` release](https://github.com/zefuros1991/ZeXOS/releases/tag/prebuilt) on GitHub, checked against the checksum in `packaging/prebuilt.list`) to `/etc/pacman.conf`, so they install with everything else in one pacman run, and `pacman -Syu` keeps them updated. If the repo can't be reached or fails its check, each package is fetched on its own: the AUR first (`<name>-bin`, only if you have `yay` or `paru`), then the GitHub release, each checksum-checked. | about 2½ minutes for the whole install on a fresh Arch |
| **2. Build here** | Builds each one on your computer from the recipes in `packaging/`. | several minutes more (Noctalia is the slow one); the builds run while pacman installs the rest |

Both give you the same packages. If a ready-made one can't be used (no download, wrong checksum, or `qt6ct-kde` was made for a different Qt than yours), that one is built here instead. To skip the question, put `ZEXOS_PACKAGES=prebuilt` or `ZEXOS_PACKAGES=source` in front of the install command. Your answer becomes the default next time.

Either way, the installer first makes a list of every package it needs, then installs them all in one pacman run instead of one run per package. If that run fails, it installs them one at a time, so the log still names the package that caused it. At the end it shows a short result for each part (✔ or ✖).

The ready-made packages are built in a clean Arch Linux container by `scripts/make-prebuilt.sh`, the same way Arch builds its own ([clean chroot builds](https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot)).

## Pick what to install

By default you get all three compositors and both shells. To install only
some, name them before running the installer:

```bash
ZEXOS_COMPOSITORS="niri mango" ZEXOS_SHELLS=noctalia bash install.sh
```

Compositors: `niri`, `hyprland`, `mango`. Shells: `noctalia`, `dms`. Your
pick is remembered, so updates keep it. With one shell, the shell switcher
is left out.

## Installer ISOs

To install Arch and ZeXOS together on an empty PC, download the installer
ISO from the [Releases page](https://github.com/zefuros1991/ZeXOS/releases/latest).
It has a graphical and a text installer; how it is built is in
[iso/README.md](../iso/README.md).

A system installed from an ISO is called **ZeXOS** (`/etc/os-release`).
Under the hood it is plain Arch and says so (`ID_LIKE=arch`), so Arch
packages, guides and the ZeXOS installer treat it as Arch. Installing ZeXOS
with the script on a system you already have keeps that system's name and
logo.

## What the installer does

`install.sh` first checks which distro you're on (and stops if it's one ZeXOS can't support), then runs four scripts from `scripts/`, in order:

1. **Bootstrap** (`bootstrap.sh`): enables the `multilib` repo if it's off, updates the system, installs the basics (`git`, `curl`, `stow`, `base-devel`, `flatpak`), adds Flathub, and clones this repo to `~/.dotfiles`.
2. **Packages** (`packages.sh`): installs the desktop (niri, Mango, Hyprland, Noctalia and its patched build, DankMaterialShell, roller, fuzzel, kitty), getting ZeXOS's own few packages ready-made or building them, as you chose (see [Fast install or build it yourself](#fast-install-or-build-it-yourself)), the basics a non-niri install may lack (portals, keyring, fonts, sound, network, Bluetooth and power services), the everyday apps, fonts, themes, and SDDM with Pixie. The few distro-specific steps come from `scripts/distro/`. If another login screen is in use (GDM, Plasma Login, ...), it switches to SDDM only after checking SDDM and Pixie are installed and ready. It skips anything already installed. It also adds a pacman hook that rebuilds the patched `qt6ct-kde` (which lets open apps like Dolphin change colour with the wallpaper) after every Qt update, since a new Qt can break it (`journalctl -u zexos-qt6ct-rebuild` shows how it went).
3. **Stow** (`stow.sh`): links every config package under `stow/` into your home folder with [GNU Stow](https://www.gnu.org/software/stow/). Any existing file in the way is first backed up to `backup/stow-<timestamp>/`.
4. **Final touches** (`finaltouches.sh`): copies the wallpapers to `~/Pictures/Wallpapers` and sets up the login-screen wallpaper sync.

Every step keeps a log in `~/.dotfiles`: `install.log`, `bootstrap.log`, `packages.log`, `stow.log` and `finaltouches.log`. If something goes wrong, look there first. Logs are gitignored.

---

[Back to the README](../README.md) · [All docs](README.md)
