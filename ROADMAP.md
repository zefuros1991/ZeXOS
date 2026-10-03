# Roadmap

Where ZeXOS is going. These are plans, not promises: the order can change,
and there are no dates. What has already shipped is in the
[changelog](CHANGELOG.md).

Version numbers work like this (see [the changelog](CHANGELOG.md#version-numbers)
for more):

- **1.0.x** — fixes only
- **1.x.0** — new features; your setup updates normally
- **x.0.0** — a big change to what ZeXOS is; updating may need a reinstall or
  manual steps

## Latest: 1.1.0 (released 2026-10-03)

- Two desktop shells, Noctalia and DankMaterialShell, with a menu to switch
  (`Mod+Shift+D`)
- Three compositors, niri, Hyprland and Mango, picked at the login screen
- Animated shell switch, `zexos-motion` and animated wallpapers
- A fast install with ready-made packages, or build everything yourself
- The gallery page with clips of every combination

Full details are in the [changelog](CHANGELOG.md).

## Next: 1.x

New features that work on top of an existing install:

- **More animation polish**, on all three compositors and both shells
- **`zexos update`**: one command that updates ZeXOS and safely moves your
  config over when a new version changes how things are set up
- **A ZeXOS package repository**: ZeXOS's own packages served as a normal
  pacman repository, so they update with the rest of the system. Planned
  with signed packages, public build logs, and automatic checks that
  building the packages yourself gives the same result
- **Closing known gaps** listed in the changelog where the shells or
  compositors allow it (for example a USB drive widget for DMS)
- **More distros tested**: more Arch-based distros checked and added to the
  tested list

## Later

- **NixOS support**: ZeXOS as a NixOS flake, so the same desktop can be
  declared in a NixOS config. NixOS doesn't use pacman or config files in
  the same way, so this is its own piece of work next to the install script

## 2.0: ZeXOS as its own distro

- **An installer ISO**: a bootable USB image that installs Arch Linux with
  ZeXOS already set up, using the ZeXOS package repository. It turns ZeXOS
  into a small Arch-based distro of its own
- **The install script stays**: anyone already on CachyOS, Arch or another
  Arch-based distro can keep adding ZeXOS to their system. The ISO runs the
  same script, so both stay the same desktop
- This is a major version because it changes how ZeXOS is installed and
  updated. Moving a script install to the distro may need a reinstall

## Not planned

- **Debian, Ubuntu, Fedora and other non-Arch distros**: they use other
  package managers and different package versions. Supporting them would
  mean a second ZeXOS, maybe one day as its own project

Ideas and requests are welcome as GitHub issues.
