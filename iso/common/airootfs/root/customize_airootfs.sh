#!/usr/bin/env bash
# Run by mkarchiso inside the live system after every package is installed,
# then deleted. The Broadcom Wi-Fi driver (wl) is built by dkms while the
# packages install, and needs the kernel headers and gcc for that. Once it is
# built they only add ~540 MB of unpacked files, so drop them here to keep the
# ISO under GitHub's 2 GiB limit for a release file. The installed system gets
# its own headers from zexos-pacstrap.
set -euo pipefail
ls /usr/lib/modules/*/updates/dkms/wl.ko* >/dev/null
pacman -Rdd --noconfirm linux-headers gcc
