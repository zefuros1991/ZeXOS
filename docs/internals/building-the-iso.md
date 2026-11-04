# Building the ISO

For contributors. How to build the installer ISO, and how the two installers on it work inside. To just install from the ISO, see [the ISO page](../../iso/README.md).

The ISO is built on Arch's own `releng` profile (from the `archiso` package) and holds both installers.

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

## Build it

Arch has no official Calamares package, so the window installer uses its own from upstream Calamares (with the QML package chooser for the picker pages), `zexos-calamares`, served from a small local repo. Everything else comes from Arch's own repos.

You need `podman`.

1. Build the package once, and again after any PKGBUILD change. It builds in a clean Arch Linux container, so it runs on any x86-64 PC.

   ```bash
   iso/gui/build-calamares.sh
   ```

   Do not build it with plain `makepkg` on a CachyOS host. Its compiler marks programs as needing a newest-generation CPU, and the installer then will not start on most laptops.

2. Build the ISO:

   ```bash
   sudo ./iso/build.sh                    # release ISO, built from main
   sudo ZEXOS_BRANCH=beta ./iso/build.sh  # test ISO, built from beta
   ```

   `ZEXOS_BRANCH` is the branch the installed system downloads ZeXOS from. It also picks the compression: `main` gives the small xz image, any other branch gives a bigger but faster-to-build zstd image.

### The file name

The ISO is named after the newest version in `CHANGELOG.md`, for example `ZeXOS-v2.0.0-x86_64.iso`. Test builds from any other branch get `-beta` after the version.

### The 2 GiB limit

GitHub refuses release files of 2 GiB or more, and the ISO is close to that. The Broadcom Wi-Fi driver is built while the packages install, and building it needs the kernel headers and gcc. `iso/common/airootfs/root/customize_airootfs.sh` runs once the driver is built and deletes both, which keeps about 540 MB out of the image. The headers are deleted by hand, not with `pacman -R`, because removing the package makes dkms delete the driver it just built. The script checks that the driver is still there before and after. The installed system gets its own headers during install.

### Making a release

1. Build from `main` with `sudo ./iso/build.sh`.
2. In `~/Projects/ZeXOS-iso/out/`, write the checksum: `sha256sum ZeXOS-v2.0.0-x86_64.iso > SHA256SUMS`.
3. Sign it in a real terminal, because the passphrase needs one: `gpg --armor --detach-sign SHA256SUMS`.
4. Check both: `gpg --verify SHA256SUMS.asc SHA256SUMS` and `sha256sum -c SHA256SUMS`.
5. Tag the release, then publish it on GitHub with the ISO, `SHA256SUMS` and `SHA256SUMS.asc` attached.

### Where the files go

Everything both steps make goes in one folder next to the repo's folder, never inside it. For `~/Projects/ZeXOS` that is `~/Projects/ZeXOS-iso`:

| Folder | Holds |
|---|---|
| `out/` | The ISOs |
| `calamares-repo/` | The `zexos-calamares` package |
| `work/` | Scratch space |

All of it belongs to you, not root, so it can be deleted without sudo. `ZEXOS_ISO_OUT`, `ZEXOS_ISO_WORK` and `ZEXOS_CALAMARES_REPO` pick other folders.

### Why a container

The build runs inside a clean Arch Linux container with Arch's own pacman and archiso, so nothing from the build computer (a CachyOS pacman, its mirrors or packages) reaches the ISO. The builder image is made on the first run and remade once a week. `ZEXOS_ISO_NATIVE=1` builds with the computer's own archiso instead.

The `[zexos-iso]` repo is only used inside the live system. The installed system gets a plain Arch `pacman.conf` (everything above the `# ZEXOS-LIVE-ONLY` line).

## The window installer (Calamares)

1. Pages: welcome, language and time zone, keyboard, disk (erase or manual), compositors, shells, user, summary.
2. Install: partitions and mounts the disk, runs `pacstrap` for a plain Arch base, writes fstab, locale, users, hostname and services, sets up systemd-boot, then runs `zexos-install-into` with the picked compositors and shells. That is the same `install.sh` you would run by hand.
3. Names the new system ZeXOS (see below).
4. Log of the ZeXOS part: `/var/log/zexos-install.log` in the new system.

Bootloader: systemd-boot only for now (UEFI). GRUB and Limine are planned.

## The text installer (`zexos-tui`)

The start menu entry adds `zexos.installer=text` to the kernel line. The live system's login on the first screen (`gui/airootfs/root/.config/fish/conf.d/zexos-live.fish`) reads it.

After the questions it writes an archinstall config (an EFI partition plus a btrfs root, encrypted if asked), runs archinstall without its menus, and puts ZeXOS on the new system before the first boot. The log is `/var/log/zexos-install.log` (also copied into the new system).

### Run it without questions, or test it

```bash
zexos-tui --answers answers.sh            # no questions
zexos-tui --answers answers.sh --dry-run  # only writes the config to /tmp/zexos
zexos-tui --demo                          # every screen, no disk is touched
```

`answers.sh` sets `USERNAME`, `PASSWORD`, `DISK` and `TIMEZONE` (needed) and `KEYMAP`, `FULLNAME`, `HOSTNAME`, `ENCRYPT`, `COMPOSITORS`, `SHELLS` (optional) as shell variables.

## The ZeXOS name

Only systems installed from this ISO are called ZeXOS. It works the way CachyOS and EndeavourOS do it:

- `zexos-branding` writes `/etc/os-release` with `NAME="ZeXOS"`, `ID=zexos` and `ID_LIKE=arch`. That file belongs to no package, and it is read before Arch's `/usr/lib/os-release`, so Arch's file is never touched.
- `ID_LIKE=arch` keeps everything treating the system as Arch, including ZeXOS's own `install.sh` (`scripts/lib-distro.sh`).
- A pacman hook, `/etc/pacman.d/hooks/zexos-branding.hook`, runs it again after `filesystem` or `lsb-release` updates. It also renames `/etc/lsb-release` when that package is installed.
- The console greeting (`/etc/issue`) already shows the name from os-release, so it needs nothing.

The source is in `common/airootfs/usr/local/share/zexos/branding/`.

## Picker previews

`customize.sh` copies `gui/previews/<id>.webp` for `niri`, `hyprland`, `mango`, `noctalia` and `dms`. A missing clip gets a "preview coming soon" placeholder, so the ISO still builds.

Clip rules:

- Clean desktop: only what is being shown.
- Compositor clips: windows opening and moving, the overview, and the wallpaper changer. No shell menus.
- Shell clips: bar menus, settings, the launcher and the power menu. No wallpaper changer.

---

[Back to internals](README.md)
