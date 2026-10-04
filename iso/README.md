# ZeXOS installer ISOs

Two live ISOs, both built on Arch's own `releng` profile (from the
`archiso` package). Both are **online** installers: they download Arch and
ZeXOS while installing.

| ISO | What you get |
|---|---|
| `tui` | Text installer: a few plain questions, one screen to check them, then it installs everything by itself. |
| `gui` | Graphical installer: Calamares on a small niri desktop, with language, disk, compositor, shell and user pages and a slideshow while it installs. |

On both you can pick any mix of compositors (niri, Hyprland, Mango) and
shells (Noctalia, DMS). Pick a single shell and the shell switcher is left
out.

## Folders

```
iso/
  build.sh          builds either ISO
  common/           files both ISOs get (zexos-install-into, ...)
  tui/              text installer extras
  gui/              graphical installer extras
    calamares-pkg/  PKGBUILD for zexos-calamares
    customize.sh    runs at build time (wallpaper, slides, previews, repo path)
    previews/       animated <id>.webp clips for the picker pages
    airootfs/etc/calamares/  settings, module configs and the zexos branding
```

## Building the text ISO

```bash
sudo pacman -S --needed archiso
sudo ZEXOS_BRANCH=beta ./iso/build.sh tui
```

## What the text installer does

`zexos-tui` asks, one step at a time: keyboard, Wi-Fi (only if there is no
cable), your name and password, computer name, time zone, disk, disk
encryption and which compositors and shells to install. Then it shows all
the answers on one screen; pick a line to change it. After that it does the
rest by itself: it writes an archinstall config (an EFI partition plus a
btrfs root, encrypted if you said yes), runs archinstall without its menus,
and puts ZeXOS on the new system before the first boot.

Installing the same way on many machines, or testing:

```bash
zexos-tui --answers answers.sh            # no questions
zexos-tui --answers answers.sh --dry-run  # only writes the config to /tmp/zexos
```

`answers.sh` sets `USERNAME`, `PASSWORD`, `DISK` and `TIMEZONE` (needed) and
`KEYMAP`, `HOSTNAME`, `ENCRYPT`, `COMPOSITORS`, `SHELLS` (optional) as
shell variables. Arch's own installer menus are still in the first menu ("Install with
Arch's own installer menus") for anything the questions don't cover.

## Building the graphical ISO

Arch has no official Calamares package, so the graphical ISO builds its own
from upstream Calamares (with the QML package chooser for the picker pages),
`zexos-calamares`, served from a small local repo. Everything else comes from
Arch's own repos.

1. Build the package once (and after a PKGBUILD change). The script builds
   it in a clean Arch Linux container (needs podman), so it runs on any
   x86-64 PC. Do not build it with plain makepkg on a CachyOS host: its
   compiler marks programs as needing a newest-generation CPU, and the
   installer then will not start on most laptops.

   ```bash
   B=/path/to/calamares-build            # any roomy folder
   iso/gui/build-calamares.sh $B/repo
   ```

2. Build the ISO, pointing at that repo:

   ```bash
   sudo ZEXOS_BRANCH=beta ZEXOS_CALAMARES_REPO=$B/repo ./iso/build.sh gui
   ```

The `[zexos-iso]` repo is only used inside the live system. The installed
system gets a plain Arch `pacman.conf` (everything above the
`# ZEXOS-LIVE-ONLY` line).

## What the graphical installer does

1. Pages: welcome, language and time zone, keyboard, disk (erase or
   manual), compositors, shells, user, summary.
2. Install: partitions and mounts the disk, `pacstrap`s a plain Arch base,
   writes fstab, locale, users, hostname and services, sets up systemd-boot,
   then runs `zexos-install-into` with the picked compositors and shells.
   That is the same `install.sh` you would run by hand.
3. Names the new system ZeXOS (see below).
4. Log of the ZeXOS part: `/var/log/zexos-install.log` in the new system.

Bootloader: systemd-boot only for now (UEFI). GRUB and Limine are planned.

## The ZeXOS name

Only systems installed from these ISOs are called ZeXOS. It works the way
CachyOS and EndeavourOS do it:

- `zexos-branding` writes `/etc/os-release` with `NAME="ZeXOS"`, `ID=zexos`
  and `ID_LIKE=arch`. That file belongs to no package, and it is read before
  Arch's `/usr/lib/os-release`, so Arch's file is never touched.
- `ID_LIKE=arch` keeps everything treating the system as Arch, including
  ZeXOS's own `install.sh` (`scripts/lib-distro.sh`).
- A pacman hook, `/etc/pacman.d/hooks/zexos-branding.hook`, runs it again
  after `filesystem` or `lsb-release` updates. It also renames
  `/etc/lsb-release` when that package is installed.
- The console greeting (`/etc/issue`) already shows the name from
  os-release, so it needs nothing.

The source is in `common/airootfs/usr/local/share/zexos/branding/`.

## Picker previews

`customize.sh` copies `gui/previews/<id>.webp` for `niri`, `hyprland`,
`mango`, `noctalia` and `dms`. A missing clip gets a "preview coming soon"
placeholder, so the ISO still builds. Clip rules:

- Clean desktop: only what is being shown.
- Compositor clips: windows opening and moving, the overview, and the
  wallpaper changer. No shell menus.
- Shell clips: bar menus, settings, the launcher and the power menu. No
  wallpaper changer.
