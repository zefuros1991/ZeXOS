#!/usr/bin/env bash
# Builds the ready-made ("prebuilt") packages for ZeXOS's own apps and puts
# them on the GitHub release "prebuilt". install.sh downloads them from
# there when you pick the fast install, instead of building them on your
# computer.
#
# For maintainers only. Needs podman and the GitHub CLI (gh), logged in.
#   scripts/make-prebuilt.sh            build + upload + update the list
#   scripts/make-prebuilt.sh --no-upload  build only (files land in dist/)
#
# Everything is built inside a fresh, plain Arch Linux container, the same
# way Arch builds its own packages (a clean system with only base-devel and
# the package's own build needs; see
# https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot).
# So the packages don't pick up anything special from the build computer,
# and they work on plain Arch, EndeavourOS and CachyOS alike.
#
# Afterwards it rewrites packaging/prebuilt.list: one line per package with
# its version, file name and checksum. install.sh only installs a download
# whose checksum matches that list. Commit the list after uploading.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GH_REPO="zefuros1991/ZeXOS"
TAG="prebuilt"
OUT="$REPO_ROOT/dist/prebuilt"
LIST="$REPO_ROOT/packaging/prebuilt.list"
PACKAGES=(noctalia-zexos pixie-sddm-zexos bibata-cursor-zexos qt6ct-kde roller mpvpaper)

upload=1
[ "${1:-}" = "--no-upload" ] && upload=0

mkdir -p "$OUT"
rm -f "$OUT"/*.pkg.tar.zst "$OUT"/qt6-base.version

podman run --rm \
    -v "$REPO_ROOT/packaging:/src:ro,Z" \
    -v "$OUT:/out:Z" \
    docker.io/library/archlinux:latest bash -euo pipefail -c '
        pacman -Syu --noconfirm --needed base-devel git >/dev/null
        useradd -m builder
        echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
        # No debug packages, and no link-time optimisation (same as install.sh).
        echo "OPTIONS+=(!debug !lto)" >> /etc/makepkg.conf
        for pkg in '"${PACKAGES[*]}"'; do
            echo "==> building $pkg"
            rm -rf /home/builder/b && mkdir /home/builder/b
            cp -r /src/$pkg/. /home/builder/b/
            chown -R builder: /home/builder/b
            (cd /home/builder/b && runuser -u builder -- makepkg -s --noconfirm)
            cp /home/builder/b/*.pkg.tar.zst /out/
        done
        # qt6ct-kde only works with the exact Qt it was built against.
        pacman -Q qt6-base | cut -d" " -f2 > /out/qt6-base.version
    '

# The list install.sh reads.
qt="$(cat "$OUT/qt6-base.version")"
{
    echo "# Written by scripts/make-prebuilt.sh -- don't edit by hand."
    echo "# Files: https://github.com/$GH_REPO/releases/tag/$TAG"
    echo "# name version file sha256 [built against Qt]"
    for pkg in "${PACKAGES[@]}"; do
        f="$(cd "$OUT" && ls "$pkg"-[0-9]*.pkg.tar.zst)"
        ver="$(. "$REPO_ROOT/packaging/$pkg/PKGBUILD"; echo "$pkgver-$pkgrel")"
        sum="$(sha256sum "$OUT/$f" | cut -d' ' -f1)"
        extra=""
        [ "$pkg" = qt6ct-kde ] && extra=" qt=$qt"
        echo "$pkg $ver $f $sum$extra"
    done
} > "$LIST"
echo "==> wrote $LIST"

if [ "$upload" = 1 ]; then
    gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1 ||
        gh release create "$TAG" -R "$GH_REPO" --title "Ready-made ZeXOS packages" \
            --notes "Packages for the fast install. install.sh picks the right files from packaging/prebuilt.list and checks their checksums. Built by scripts/make-prebuilt.sh in a clean Arch container."
    # Old files stay, so older ZeXOS versions can still find theirs.
    gh release upload "$TAG" -R "$GH_REPO" --clobber "$OUT"/*.pkg.tar.zst
    echo "==> uploaded to https://github.com/$GH_REPO/releases/tag/$TAG"
fi
