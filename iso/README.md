# ZeXOS installer ISO

One live ISO with both installers, built on Arch's own `releng` profile
(from the `archiso` package). The stick's start menu picks one:

| Start menu entry | What you get |
|---|---|
| ZeXOS (window installer) | Calamares on a small niri desktop, with language, disk, compositor, shell, drivers and user pages and a slideshow while it installs. The default. |
| ZeXOS (text installer) | `zexos-tui`: the ZeXOS logo, one plain question per screen, a summary to check, then a progress screen while it installs. |
| ZeXOS (safe graphics) | The window installer with basic graphics, for a card that shows a black screen. |

Both are **online** installers: they download Arch and ZeXOS while
installing. On both you can pick any mix of compositors (niri, Hyprland,
Mango) and shells (Noctalia, DMS). Pick a single shell and the shell
switcher is left out. The text entry adds `zexos.installer=text` to the
kernel line; the live system's login on the first screen
(`gui/airootfs/root/.config/fish/conf.d/zexos-live.fish`) reads it.

## Folders

```
iso/
  build.sh          builds the ISO
  common/           files the ISO always gets (zexos-install-into, the start menu entries)
  gui/              window installer
    calamares-pkg/  PKGBUILD for zexos-calamares
    customize.sh    runs at build time (wallpaper, slides, previews, repo path)
    previews/       animated <id>.webp clips for the picker pages
    airootfs/etc/calamares/  settings, module configs and the zexos branding
  tui/              text installer (zexos-tui)
```

## What the text installer does

`zexos-tui` asks, one step at a time: Wi-Fi (only if there is no cable;
Tab shows the password you typed), keyboard, your name and username,
password, computer name, time zone, disk, disk encryption (No by default,
like the window installer), compositors and shells, and drivers. Then it
shows all the answers on one screen; "Change something" jumps to any step.
Esc always goes one step back.

After that it does the rest by itself: it writes an archinstall config (an
EFI partition plus a btrfs root, encrypted if you said yes), runs archinstall
without its menus, and puts ZeXOS on the new system before the first boot.
The install screen shows a progress bar, what it is doing and tips; V shows
the live output. The log is `/var/log/zexos-install.log` (also copied into
the new system).

Installing the same way on many machines, or testing:

```bash
zexos-tui --answers answers.sh            # no questions
zexos-tui --answers answers.sh --dry-run  # only writes the config to /tmp/zexos
zexos-tui --demo                          # every screen, no disk is touched
```

`answers.sh` sets `USERNAME`, `PASSWORD`, `DISK` and `TIMEZONE` (needed) and
`KEYMAP`, `FULLNAME`, `HOSTNAME`, `ENCRYPT`, `COMPOSITORS`, `SHELLS` (optional)
as shell variables.

## Building the ISO

Arch has no official Calamares package, so the window installer uses its own
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

2. Build the ISO, pointing at that repo (needs podman):

   ```bash
   sudo ZEXOS_BRANCH=beta ZEXOS_CALAMARES_REPO=$B/repo ./iso/build.sh
   ```

   The build runs inside a clean Arch Linux container with Arch's own pacman
   and archiso, so nothing from the build computer (a CachyOS pacman, its
   mirrors or packages) reaches the ISO. The builder image is made on the
   first run and remade once a week. `ZEXOS_ISO_NATIVE=1` builds with the
   computer's own archiso instead.

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

Only systems installed from this ISO are called ZeXOS. It works the way
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
