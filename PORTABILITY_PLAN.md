# ZeXOS portability plan

Written 2026-07-16, after the first fresh-VM test of this repo (CachyOS +
niri + Noctalia, chosen from live media). That run went end-to-end and
niri/Noctalia came up correctly after reboot — the early-XDG setup work
paid off. It also surfaced the gaps this document is about: Steam didn't
install (interactive lib32 prompt), Millennium failed as a knock-on effect,
gparted hit the same pkexec issue already fixed once on the laptop, and
monique was still being installed even though it's gone from the laptop.
Those specific bugs are already fixed as of this writing (see the commits
alongside this file). This document is the longer-term map: what it takes
to get this repo to "works on any fresh CachyOS install, any hardware" —
and, further out, "works on any Arch-based distro." Nothing here is
implemented yet beyond the fixes already landed; it's the direction to
build toward.

## Where this repo stands today

- Confirmed working end-to-end on: this laptop (hybrid AMD iGPU / NVIDIA
  dGPU, real hardware) and a QEMU/libvirt VM (`CachyOStest`, virtio-gpu +
  3D accel, see the VM note below).
- Hardware-specific material still lives in the repo by design (this is
  still primarily a personal dotfiles repo) — GPU MUX switching functions
  in `.zshrc`, kanshi profiles keyed to this laptop's exact monitor EDIDs,
  the `niri`/`rules.kdl` `render-drm-device` pin, the NVMe fstab entry
  (system-level, not even in the repo). None of that is meant to run
  unmodified on someone else's machine, and that's fine — it just needs to
  fail *quietly and safely* on hardware where it doesn't apply, not break
  the rest of the install.
- Everything under `scripts/` (bootstrap → packages → stow →
  finaltouches) is the part that should become hardware-agnostic. That's
  the realistic scope for "any fresh CachyOS install."

## Target 1: any fresh CachyOS install, any hardware (NVIDIA/AMD/Intel/VM)

This is the near-term, buildable goal. Concrete gaps to close, roughly in
priority order:

1. **GPU-conditional packages, generalized.** The Steam/Vulkan fix just
   landed (`detect_gpu_vendors` in `packages.sh`) is the first instance of
   a pattern this repo needs more of: detect hardware, then choose
   packages, rather than assuming one hardware profile. Other places this
   same pattern should eventually apply:
   - Full NVIDIA driver stack (kernel module choice: `nvidia-open-dkms` vs
     `nvidia-dkms` vs `nvidia` depends on GPU generation and kernel) is
     currently *not* installed by this repo at all — it assumes whatever
     the CachyOS installer already set up. That's a reasonable line to
     hold (driver/kernel-module setup is arguably installer territory, not
     dotfiles territory) but worth stating explicitly rather than leaving
     implicit.
   - `gpu-game`/`gpu-battery` MUX switching is laptop-specific and correctly
     lives outside `scripts/` (in `.zshrc`) — leave it there, but make sure
     nothing in `scripts/` assumes a MUX-capable machine exists.
2. **Multilib can't be assumed.** Fixed as of this writing
   (`bootstrap.sh` now checks/enables it) — flagging here so the reasoning
   doesn't get lost: CachyOS's niri/noctalia profile happens to enable it,
   but that's a property of the install profile, not a guarantee, and
   plain Arch never enables it by default.
3. **No install step should require a human to answer a prompt.**
   The general rule the Steam fix follows: any virtual/ambiguous pacman
   dependency needs to be resolved by explicit package choice *before* the
   ambiguous one is pulled in, never left to `--noconfirm` to guess right
   (it won't — `--noconfirm` only answers yes/no, not provider-selection
   prompts). Audit every AUR/pacman call for this pattern periodically, not
   just Steam.
4. **AUR build fragility, acknowledged not solved.** `millennium` (heavy
   `rust`/`cmake`/`ninja`/`bun` build), `pixie-sddm-git`, `spicetify` are
   all AUR packages this repo depends on with no fallback if the build
   breaks upstream. `install_aur`/`install_pacman` already do the right
   thing operationally (report failure per-package, don't abort the whole
   run) — that's the correct posture for a rolling-release AUR dependency.
   No further fix planned; just don't be surprised when an AUR package
   breaks upstream and needs a one-off patch someday.
5. **VM testing caveat (not a script bug, but worth recording):** a
   plain `virtio-gpu` VM without 3D acceleration black-screens niri after
   login (Smithay has no software-rendering fallback). Any future VM used
   to test this repo needs `virtio-vga-gl` + `accel3d=yes` + SPICE GL on
   the host side — this is a hypervisor config question, not something
   `scripts/` can detect or fix from inside the guest. Worth a line in
   README's testing notes so this doesn't get rediscovered from scratch.
6. **pciutils dependency.** `lspci` (used for GPU detection) isn't part of
   `base`/`base-devel` — `packages.sh` now installs it defensively the
   first time it's needed, but if GPU detection logic grows, make sure any
   new hardware-probing step keeps its own tool dependency explicit rather
   than assuming it's already on the system.
7. **Display/monitor config should degrade gracefully on unknown
   hardware.** The kanshi profiles and `niri/monitors.kdl` are keyed to
   this laptop's exact EDID strings. On different hardware they simply
   won't match anything — confirm that's a silent no-op (niri's own
   default hotplug/auto-enable behavior takes over) rather than an error,
   so a fresh install on different hardware still ends up with a usable
   display instead of a black screen from a config that assumes monitors
   that don't exist. Not yet verified either way — flagging as an open
   question, not a confirmed bug.

## Target 2 (longer term, not being built now): any Arch-based distro

The user's stated direction: eventually make this usable on Arch, CachyOS,
PikaOS, etc. — the popular-portable-dotfiles-repo model (stow-based repos
like this one are already halfway there structurally). Things that would
need to change, for later:

- **CachyOS-specific packages need Arch equivalents or graceful skip.**
  `cachyos-gaming-meta`, `cachyos-gaming-applications`, `cachyos-hello`-style
  meta packages, kernel/scheduler-specific tuning, the Pixie SDDM theme (CachyOS
  AUR) don't exist outside CachyOS's repos. A portable version would need
  either a plain-Arch equivalent package list as a fallback, or a
  CachyOS-vs-generic-Arch branch in `packages.sh`.
- **Repo/mirror assumptions.** Scripts currently assume `cachyos-*` repos
  exist in `pacman.conf` implicitly (never checked, just assumed present
  because this machine has them). A distro-detection step (`/etc/os-release`
  or similar) deciding which package list to run would be the natural
  place to branch.
- **DE/WM choice hardcoded to niri+Noctalia.** Fine for now (that's what
  was explicitly asked for), but a genuinely portable repo would need this
  to be a choice, not an assumption baked into `stow/` package names.
- **Distro-specific bootstrap differences.** AUR helper bootstrapping
  (`yay` via `makepkg`) is Arch/CachyOS-only; a distro like PikaOS (if it's
  not a plain Arch derivative with AUR) would need its own package-fetch
  path entirely.
- **Suggested approach when this is actually tackled:** don't try to
  abstract everything at once. Start by adding an explicit hardware/distro
  detection layer (a small `scripts/lib-detect.sh`, mirroring the existing
  `lib-xdg.sh` pattern) that the rest of the scripts query instead of
  assuming — GPU vendor detection from this fix is the first real piece of
  that layer and can be lifted out of `packages.sh` into it once a second
  detection need shows up.

This is explicitly a "not now" list — recorded so the direction is clear
next time this repo gets worked on, not a queue of tasks to start today.
