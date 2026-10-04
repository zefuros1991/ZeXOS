#!/usr/bin/env bash
# Builds the zexos-calamares package inside a clean Arch Linux container and
# puts it in a local repo for the graphical ISO.
#
#   iso/gui/build-calamares.sh /path/to/calamares-build/repo
#
# Why a container: a CachyOS compiler marks every program it builds as
# "needs an x86-64-v4 CPU", even with generic flags. The installer then
# refuses to start on most laptops ("CPU ISA level is lower than required").
# Plain Arch builds for any x86-64 PC.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=${1:?usage: build-calamares.sh REPO_DIR}
mkdir -p "$repo"
repo=$(cd "$repo" && pwd)
rm -f "$repo"/zexos-calamares-*.pkg.tar.zst "$repo"/zexos-iso.*

podman run --rm \
    -v "$here/calamares-pkg:/src:ro,Z" \
    -v "$repo:/out:Z" \
    docker.io/library/archlinux:latest bash -euo pipefail -c '
        pacman -Syu --noconfirm --needed base-devel git >/dev/null
        useradd -m builder
        echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
        echo "OPTIONS+=(!debug !lto)" >> /etc/makepkg.conf
        mkdir /home/builder/b && cp /src/PKGBUILD /home/builder/b/
        chown -R builder: /home/builder/b
        deps=$(cd /home/builder/b && source PKGBUILD && echo "${depends[@]}" "${makedepends[@]}")
        pacman -S --noconfirm --needed $deps >/dev/null
        (cd /home/builder/b && runuser -u builder -- makepkg --noconfirm)
        cp /home/builder/b/*.pkg.tar.zst /out/
        cd /out && repo-add zexos-iso.db.tar.gz zexos-calamares-*.pkg.tar.zst
    '

# Check it really runs on older CPUs: the program must only *need* basic
# x86-64 ("ISA used" may list newer levels, picked at run time when present).
tmp=$(mktemp -d)
bsdtar -xf "$repo"/zexos-calamares-*.pkg.tar.zst -C "$tmp" usr/bin/calamares
if readelf -n "$tmp/usr/bin/calamares" | grep 'ISA needed' | grep -q 'x86-64-v[234]'; then
    echo "ERROR: calamares is marked for a newer CPU than x86-64" >&2
    rm -rf "$tmp"; exit 1
fi
rm -rf "$tmp"
echo "OK: $repo"
