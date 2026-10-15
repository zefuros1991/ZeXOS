#!/usr/bin/env bash
# Builds the ready-made ("prebuilt") packages for ZeXOS's own apps and puts
# them on the GitHub release "prebuilt". install.sh downloads them from
# there when you pick the fast install, instead of building them on your
# computer.
#
# For maintainers only. Needs podman, repo-add (pacman) and the GitHub CLI
# (gh), logged in.
#   scripts/make-prebuilt.sh              build + upload + update the list
#   scripts/make-prebuilt.sh --no-upload  build + sign only (files land in dist/)
#   scripts/make-prebuilt.sh --no-sign    test build: unsigned, never uploaded
#   scripts/make-prebuilt.sh --db-only    don't build: fetch the packages
#                                         already on the release and only
#                                         remake + upload the repo list
#   scripts/make-prebuilt.sh --only roller[,mpvpaper]
#                                         build just these; the others are
#                                         fetched from the release as the
#                                         list names them (much faster when
#                                         only one PKGBUILD changed). Works
#                                         with --no-upload too.
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
#
# It also makes zexos.db (and zexos.files) with repo-add, which turns the
# release into a pacman repo: install.sh adds it to /etc/pacman.conf, so
# pacman installs and updates the packages like any other. The list holds
# zexos.db's checksum too, and install.sh checks it before using the repo.
# See https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Custom_local_repository
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GH_REPO="zefuros1991/ZeXOS"
TAG="prebuilt"
OUT="$REPO_ROOT/dist/prebuilt"
LIST="$REPO_ROOT/packaging/prebuilt.list"
# Built in this order: a recipe may need packages an earlier one made
# (nvidia-580xx-settings and lib32-nvidia-580xx-utils need nvidia-580xx-utils).
PACKAGES=(zexos-keyring noctalia-zexos pixie-sddm-zexos bibata-cursor-zexos qt6ct-kde roller mpvpaper mango-overview
          zexos-gaming-meta zexos-gaming-applications zexos-drivers
          nvidia-580xx-utils nvidia-580xx-settings lib32-nvidia-580xx-utils r8168-dkms)
# Every package is signed with the ZeXOS key (see packaging/zexos-keyring).
SIGN_KEY="${ZEXOS_SIGN_KEY:-A7806D3AD3119C44D4C1D4228DCA6BDAF6F88F95}"

upload=1 build=1 sign=1
BUILD=("${PACKAGES[@]}")
while [ $# -gt 0 ]; do
    case "$1" in
        --no-upload) upload=0 ;;
        --no-sign)   sign=0 upload=0 ;;   # test build only: unsigned, so never uploaded
        --db-only) build=0 BUILD=() ;;
        --only)
            [ -n "${2:-}" ] || { echo "--only needs package names, e.g. --only roller" >&2; exit 1; }
            IFS=, read -ra BUILD <<< "$2"
            for b in "${BUILD[@]}"; do
                [[ " ${PACKAGES[*]} " == *" $b "* ]] || { echo "unknown package: $b (known: ${PACKAGES[*]})" >&2; exit 1; }
            done
            shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done
building() { [[ " ${BUILD[*]} " == *" $1 "* ]]; }
# A test build (--no-sign) leaves the real list alone.
LIST_OUT="$LIST"; [ "$sign" = 1 ] || LIST_OUT="$OUT/prebuilt.list.test"

mkdir -p "$OUT"
rm -f "$OUT"/*.pkg.tar.zst "$OUT"/*.sig "$OUT"/qt6-base.version "$OUT"/zexos.* "$OUT"/built.list

# Every package we don't build now: the file the list names, checked
# against it. Its version stays what the list says, even if a PKGBUILD
# has moved on since.
# A recipe can make several packages (from=<recipe> says which made it).
from_of() { local x; for x in "$@"; do [[ "$x" == from=* ]] && { echo "${x#from=}"; return 0; }; done; return 0; }
grep -v '^#' "$LIST" | while read -r name ver file sum extra; do
    [ "$name" = zexos.db ] && continue
    building "$name" && continue
    src="$(from_of $extra)"; [ -n "$src" ] && building "$src" && continue
    echo "==> fetching $file"
    curl -fsSL --retry 3 -o "$OUT/$file" "https://github.com/$GH_REPO/releases/download/$TAG/$file"
    echo "$sum  $OUT/$file" | sha256sum -c --quiet -
done

if [ "$build" = 1 ]; then
podman run --rm \
    -v "$REPO_ROOT/packaging:/src:ro,Z" \
    -v "$OUT:/out:Z" \
    docker.io/library/archlinux:latest bash -euo pipefail -c '
        # The 32-bit source: lib32-nvidia-580xx-utils needs it.
        printf "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" >> /etc/pacman.conf
        pacman -Syu --noconfirm --needed base-devel git >/dev/null
        useradd -m builder
        echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
        # No debug packages, and no link-time optimisation (same as install.sh).
        echo "OPTIONS+=(!debug !lto)" >> /etc/makepkg.conf
        for pkg in '"${BUILD[*]}"'; do
            echo "==> building $pkg"
            rm -rf /home/builder/b && mkdir /home/builder/b
            cp -r /src/$pkg/. /home/builder/b/
            chown -R builder: /home/builder/b
            # Meta packages (the gaming ones) hold no files, only a list of
            # other packages: pack them without installing that list first
            # (it needs multilib and is gigabytes of Steam, Wine...). pacman
            # still checks every dependency on the computer installing them.
            case "$pkg" in
                zexos-gaming-*) deps=-d ;;
                *)              deps=-s ;;
            esac
            (cd /home/builder/b && runuser -u builder -- makepkg $deps --noconfirm)
            for f in /home/builder/b/*.pkg.tar.zst; do
                cp "$f" /out/
                echo "$pkg $(basename "$f")" >> /out/built.list
            done
            # Later recipes may need what this one made (not the meta packages,
            # and not the -dkms ones: they would try to build kernel modules here).
            inst=$(ls /home/builder/b/*.pkg.tar.zst | grep -vE -- "-dkms-|/zexos-gaming-" || true)
            [ "$deps" = -s ] && [ -n "$inst" ] && pacman -U --noconfirm $inst >/dev/null
        done
        # qt6ct-kde only works with the exact Qt it was built against.
        # (Only there when a Qt package was built; --only can leave it out.)
        if pacman -Q qt6-base >/dev/null 2>&1; then
            pacman -Q qt6-base | cut -d" " -f2 > /out/qt6-base.version
        fi
    '
fi

# Sign every package (fetched ones too, so the whole source ends up signed).
# gpg asks for the key's passphrase once (a window pops up), then caches it.
for f in "$OUT"/*.pkg.tar.zst; do
    [ "$sign" = 1 ] || break
    if curl -fsSL --retry 2 -o "$f.sig" "https://github.com/$GH_REPO/releases/download/$TAG/$(basename "$f").sig" 2>/dev/null &&
       gpg --batch --verify "$f.sig" "$f" >/dev/null 2>&1; then continue; fi
    rm -f "$f.sig"
    gpg --batch --yes --local-user "$SIGN_KEY" --detach-sign --no-armor -o "$f.sig" "$f" || { echo "signing $f failed (is the ZeXOS key unlocked?)" >&2; exit 1; }
done

# The repo list pacman reads. repo-add makes zexos.db.tar.gz plus a link
# zexos.db; GitHub can't hold links, so real copies go up. The list is
# signed too (zexos.db.sig).
if [ "$sign" = 1 ]; then
    repo-add -q --sign --key "$SIGN_KEY" "$OUT/zexos.db.tar.gz" "$OUT"/*.pkg.tar.zst
    cp -L "$OUT/zexos.db.tar.gz.sig" "$OUT/zexos.db.sig.real"
    cp -L "$OUT/zexos.files.tar.gz.sig" "$OUT/zexos.files.sig.real"
    rm -f "$OUT/zexos.db.sig" "$OUT/zexos.files.sig"
    mv "$OUT/zexos.db.sig.real" "$OUT/zexos.db.sig"
    mv "$OUT/zexos.files.sig.real" "$OUT/zexos.files.sig"
else
    repo-add -q "$OUT/zexos.db.tar.gz" "$OUT"/*.pkg.tar.zst
fi
cp -L "$OUT/zexos.db.tar.gz" "$OUT/zexos.db.real"
cp -L "$OUT/zexos.files.tar.gz" "$OUT/zexos.files.real"
rm -f "$OUT/zexos.db" "$OUT/zexos.files"
mv "$OUT/zexos.db.real" "$OUT/zexos.db"
mv "$OUT/zexos.files.real" "$OUT/zexos.files"
db_line="zexos.db repo zexos.db $(sha256sum "$OUT/zexos.db" | cut -d' ' -f1)"

# The list install.sh reads.
if [ "$build" = 0 ]; then
    { grep -v '^zexos\.db ' "$LIST"; echo "$db_line"; } > "$LIST.new"
    mv "$LIST.new" "$LIST_OUT"
else
    qt="$(cat "$OUT/qt6-base.version" 2>/dev/null || true)"   # empty when no Qt package was built
    {
        echo "# Written by scripts/make-prebuilt.sh -- don't edit by hand."
        echo "# Files: https://github.com/$GH_REPO/releases/tag/$TAG"
        echo "# name version file sha256 [built against Qt]"
        # Not rebuilt now: keep their lines exactly as they were.
        grep -v '^#' "$LIST" | while read -r name ver file sum extra; do
            [ "$name" = zexos.db ] && continue
            building "$name" && continue
            src="$(from_of $extra)"; [ -n "$src" ] && building "$src" && continue
            echo "$name $ver $file $sum${extra:+ $extra}"
        done
        # Every package made now (a recipe can make several).
        while read -r recipe f; do
            info="$(bsdtar -xOf "$OUT/$f" .PKGINFO)"
            name="$(sed -n 's/^pkgname = //p' <<<"$info")"; ver="$(sed -n 's/^pkgver = //p' <<<"$info")"
            sum="$(sha256sum "$OUT/$f" | cut -d' ' -f1)"
            extra=""
            case $name in qt6ct-kde|mango-overview) extra=" qt=$qt" ;; esac
            [ "$name" != "$recipe" ] && extra="$extra from=$recipe"
            echo "$name $ver $f $sum$extra"
        done < "$OUT/built.list"
        echo "$db_line"
    } > "$LIST.new"
    mv "$LIST.new" "$LIST_OUT"
fi
echo "==> wrote $LIST_OUT"

if [ "$upload" = 1 ]; then
    gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1 ||
        gh release create "$TAG" -R "$GH_REPO" --title "Ready-made ZeXOS packages" \
            --notes "Packages for the fast install. install.sh picks the right files from packaging/prebuilt.list and checks their checksums. Built by scripts/make-prebuilt.sh in a clean Arch container."
    # Old files stay, so older ZeXOS versions can still find theirs.
    # zexos.db goes up last, so it never lists a file that isn't there yet.
    # Only the packages built now; the fetched ones are already there.
    if [ "$build" = 1 ]; then
        built=()
        while read -r recipe f; do built+=("$OUT/$f"); done < "$OUT/built.list"
        gh release upload "$TAG" -R "$GH_REPO" --clobber "${built[@]}"
    fi
    # Every signature (new and fetched packages), then the signed list last.
    gh release upload "$TAG" -R "$GH_REPO" --clobber "$OUT"/*.pkg.tar.zst.sig
    gh release upload "$TAG" -R "$GH_REPO" --clobber "$OUT/zexos.files" "$OUT/zexos.files.sig" "$OUT/zexos.db.sig" "$OUT/zexos.db"
    echo "==> uploaded to https://github.com/$GH_REPO/releases/tag/$TAG"
fi
