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
#
# To be quick, the container isn't set up from nothing each time:
# - a ready-made builder image (zexos-calamares-builder) already has the
#   build tools and Calamares' needs. It is remade when the PKGBUILD's
#   package lists change or once it is a week old, and every build still
#   updates it to today's Arch first, so the installer always matches the
#   Qt on the ISO.
# - three podman volumes, used only by this builder, keep what earlier
#   builds already did: compiled pieces (ccache, so a small patch only
#   recompiles the files it touches), downloaded Arch packages, and the
#   Calamares source. They are never the build computer's own package cache
#   or files, so nothing from it reaches the ISO.
#   Start from scratch: podman volume rm zexos-calamares-{ccache,pkgcache,src}
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=${1:?usage: build-calamares.sh REPO_DIR}
mkdir -p "$repo"
repo=$(cd "$repo" && pwd)
rm -f "$repo"/zexos-calamares-*.pkg.tar.zst "$repo"/zexos-iso.*

image=zexos-calamares-builder
deps=$(source "$here/calamares-pkg/PKGBUILD" && echo "${depends[@]}" "${makedepends[@]}")
want=$(echo "$deps" | sha256sum | cut -c1-16)
have=$(podman image inspect -f '{{index .Labels "zexos.deps"}}' "$image" 2>/dev/null || true)
made=$(podman image inspect -f '{{.Created.Unix}}' "$image" 2>/dev/null || echo 0)
if [ "$have" != "$want" ] || [ $(( $(date +%s) - made )) -gt $(( 7 * 86400 )) ]; then
    echo "Making the builder image (only when it's new, old or its packages changed)..."
    podman build --pull=always --label "zexos.deps=$want" -t "$image" -f - <<EOF
FROM docker.io/library/archlinux:latest
RUN pacman -Syu --noconfirm --needed base-devel git ccache $deps && pacman -Scc --noconfirm
RUN useradd -m builder && echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder \
 && echo "OPTIONS+=(!debug !lto)" >> /etc/makepkg.conf \
 && echo "BUILDENV=(!distcc color ccache check !sign)" >> /etc/makepkg.conf
EOF
fi

podman run --rm \
    -v "$here/calamares-pkg:/src:ro,Z" \
    -v "$repo:/out:Z" \
    -v zexos-calamares-ccache:/ccache:Z \
    -v zexos-calamares-pkgcache:/var/cache/pacman/pkg:Z \
    -v zexos-calamares-src:/srcdest:Z \
    -e CCACHE_DIR=/ccache -e SRCDEST=/srcdest \
    "$image" bash -euo pipefail -c '
        pacman -Syu --noconfirm --needed '"$deps"' >/dev/null
        chown builder: /ccache /srcdest
        mkdir /home/builder/b && cp /src/PKGBUILD /home/builder/b/
        chown -R builder: /home/builder/b
        (cd /home/builder/b && runuser -u builder -- env CCACHE_DIR=/ccache SRCDEST=/srcdest makepkg --noconfirm)
        runuser -u builder -- env CCACHE_DIR=/ccache ccache -s | grep -iE "hits|misses" || true
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
