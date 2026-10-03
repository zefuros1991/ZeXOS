# ZeXOS installer ISOs

Two live ISOs, both built on Arch's own `releng` profile (from the
`archiso` package). Both are **online** installers: they download Arch and
ZeXOS while installing.

| ISO | What you get |
|---|---|
| `tui` | Text installer: archinstall for the base system, then a ZeXOS menu to pick compositors and shells. |
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

## Building the graphical ISO

The picker pages need Calamares' QML package chooser, which Arch's and
CachyOS's packages leave out. So the graphical ISO uses its own Calamares
package, `zexos-calamares`, served from a small local repo.

1. Build the package once (and after a PKGBUILD change). Use a clean
   environment and generic CPU flags, so the binary runs on any x86-64 PC
   and does not pick up a Python from your home folder:

   ```bash
   B=/path/to/calamares-build            # any roomy folder
   mkdir -p $B/repo
   sed 's/-march=native/-march=x86-64 -mtune=generic/' /etc/makepkg.conf > $B/makepkg.conf
   cd iso/gui/calamares-pkg
   env -i HOME=$HOME USER=$USER PATH=/usr/bin:/bin LANG=C.UTF-8 PKGDEST=$B/repo \
       makepkg -s --config $B/makepkg.conf
   repo-add $B/repo/zexos-iso.db.tar.gz $B/repo/zexos-calamares-*.pkg.tar.zst
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
3. Log of the ZeXOS part: `/var/log/zexos-install.log` in the new system.

Bootloader: systemd-boot only for now (UEFI). GRUB and Limine are planned.

## Picker previews

`customize.sh` copies `gui/previews/<id>.webp` for `niri`, `hyprland`,
`mango`, `noctalia` and `dms`. A missing clip gets a "preview coming soon"
placeholder, so the ISO still builds. Clip rules:

- Clean desktop: only what is being shown.
- Compositor clips: windows opening and moving, the overview, and the
  wallpaper changer. No shell menus.
- Shell clips: bar menus, settings, the launcher and the power menu. No
  wallpaper changer.
