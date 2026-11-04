# Roadmap

Where ZeXOS is going. These are plans, not promises: the order can change,
and there are no dates. Everything that has already shipped is in the
[changelog](CHANGELOG.md), which also explains the
[version numbers](CHANGELOG.md#version-numbers).

## Next: 2.x

New features that work on top of an existing install:

- **More animation polish**, on all three compositors and both shells
- **Cheaper animated wallpapers**: the video wallpaper (mpvpaper) takes about
  half of an integrated graphics chip. Look at how other distros do it and
  change it at the root, for example animated pictures instead of video. A
  small patch update after 2.0.0.
- **`zexos update`**: one command that updates ZeXOS and safely moves your
  config over when a new version changes how things are set up
- **A more open package repo**: public build logs, and automatic checks that
  building the packages yourself gives the same result
- **An offline installer ISO**: a USB image that installs without needing an
  internet connection
- **Closing known issues** listed in the changelog where the shells or
  compositors allow it (for example a USB drive widget for DMS)
- **More distros tested**: more Arch-based distros checked and added to the
  tested list

## Later

- **Limine bootloader option**: choose Limine instead of systemd-boot at
  install time. With a btrfs disk it makes every snapshot a boot entry, so
  you can boot back into a working system if an update goes wrong
- **Shell switcher as its own project**: the Noctalia/DMS switcher, usable on
  any Arch install that has both shells. Backdrops, logo animations and menu
  styles (with previews, plain list, or none) become small swappable pieces
  you pick in one settings file, so new ones can be added later
- **Try dropping Nautilus**: `xdg-desktop-portal-gnome` (needed for OBS screen
  capture on niri) pulls in the Nautilus file manager, which ZeXOS does not
  use. Test whether `xdg-desktop-portal-gtk` or a smaller setup captures the
  screen just as well, and only then change it
- **NixOS support**: ZeXOS as a NixOS flake, so the same desktop can be
  declared in a NixOS config. NixOS doesn't use pacman or config files in
  the same way, so this is its own piece of work next to the install script

## Not planned

- **Debian, Ubuntu, Fedora and other non-Arch distros**: they use other
  package managers and different package versions. Supporting them would
  mean a second ZeXOS, maybe one day as its own project

Ideas and requests are welcome as GitHub issues.
