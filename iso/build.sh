#!/usr/bin/env bash
# Builds the ZeXOS installer ISO on top of Arch's own live ISO profile
# (releng, from the archiso package).
#
#   sudo ZEXOS_CALAMARES_REPO=... ./iso/build.sh
#
# One ISO with both installers; the stick's start menu picks one:
#   ZeXOS (window installer)  the live desktop with Calamares (iso/gui)
#   ZeXOS (text installer)    zexos-tui in text screens (iso/tui)
#   ZeXOS (safe graphics)     the window installer with basic graphics
# Both are online installers: they download Arch and ZeXOS while installing.
#
# Settings (environment):
#   ZEXOS_BRANCH   branch the ISO installs (default main; beta for testing)
#   ZEXOS_ISO_OUT  where the .iso goes          (default ./out)
#   ZEXOS_ISO_WORK scratch space, several GB    (default /var/tmp/zexos-iso)
#   ZEXOS_CALAMARES_REPO  folder with the zexos-calamares package and its
#                  zexos-iso.db (see iso/README.md)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
    "") ;;
    tui|gui) echo "There is one ISO now, with both installers: run sudo $0 (no tui/gui)." >&2; exit 1 ;;
    *) echo "usage: sudo ZEXOS_CALAMARES_REPO=... $0" >&2; exit 1 ;;
esac
variant=zexos
if [ "$(id -u)" -ne 0 ]; then
    echo "mkarchiso needs root: run this with sudo." >&2
    exit 1
fi

BRANCH="${ZEXOS_BRANCH:-main}"
OUT="${ZEXOS_ISO_OUT:-$PWD/out}"
WORK="${ZEXOS_ISO_WORK:-/var/tmp/zexos-iso}"

# The ISO is made inside a clean Arch Linux container, never with this
# computer's own pacman and archiso: on CachyOS, its pacman writes fields of
# its own into the stick's package list, and the stick's pacman then warns
# "unknown key '%INSTALLED_DB%'" for every package. The builder image is
# ready-made (archiso and the image tools) and remade once a week; every
# build updates it to today's Arch first, keeping its downloads in
# $WORK/builder-pkg. This folder goes in read-only; only $OUT and $WORK are
# written. It uses this computer's network as it is (root podman's own
# network can be blocked by the firewall). ZEXOS_ISO_NATIVE=1 builds with
# this computer's tools instead.
if [ ! -e /run/.containerenv ] && [ "${ZEXOS_ISO_NATIVE:-0}" != 1 ]; then
    command -v podman >/dev/null || { echo "Install podman, or set ZEXOS_ISO_NATIVE=1." >&2; exit 1; }
    image=zexos-iso-builder
    tools="archiso imagemagick librsvg python"
    made=$(podman image inspect -f '{{.Created.Unix}}' "$image" 2>/dev/null || echo 0)
    if [ $(( $(date +%s) - made )) -gt $(( 7 * 86400 )) ]; then
        echo "Making the ISO builder image (only when it's new or a week old)..."
        podman build --network host --pull=always -t "$image" -f - <<EOF
FROM docker.io/library/archlinux:latest
RUN pacman -Syu --noconfirm --needed $tools && pacman -Scc --noconfirm
EOF
    fi
    mkdir -p "$OUT" "$WORK/builder-pkg"
    args=(-v "$here/..:/zexos:ro" -v "$OUT:/out" -v "$WORK:/work"
          -v "$WORK/builder-pkg:/var/cache/pacman/pkg"
          -e ZEXOS_BRANCH="$BRANCH" -e ZEXOS_ISO_OUT=/out -e ZEXOS_ISO_WORK=/work
          -e ZEXOS_ISO_COMPRESS="${ZEXOS_ISO_COMPRESS:-}"
          -e SUDO_UID="${SUDO_UID:-0}" -e SUDO_GID="${SUDO_GID:-0}")
    calrepo="${ZEXOS_CALAMARES_REPO:?Set ZEXOS_CALAMARES_REPO to a folder with zexos-iso.db (see iso/README.md).}"
    args+=(-v "$(cd "$calrepo" && pwd):/calrepo:ro" -e ZEXOS_CALAMARES_REPO=/calrepo)
    exec podman run --rm --privileged --network host "${args[@]}" "$image" bash -c \
        "pacman -Syu --noconfirm --needed $tools >/dev/null && exec bash /zexos/iso/build.sh"
fi
command -v mkarchiso >/dev/null || { echo "Install archiso first: sudo pacman -S archiso" >&2; exit 1; }
profile="$WORK/profile-$variant"

mkdir -p "$WORK" "$OUT"
# The build runs as root, but the ISOs are yours: hand the output folder back
# to whoever ran sudo, so old ISOs can be deleted without sudo.
owner="${SUDO_UID:-0}:${SUDO_GID:-0}"
chown "$owner" "$OUT"
# Two builds at once would write over each other's files.
exec 9>"$WORK/.lock"
flock -n 9 || { echo "Another ISO build is running (lock: $WORK/.lock)." >&2; exit 1; }
rm -rf "$profile" "$WORK/work-$variant"
cp -a /usr/share/archiso/configs/releng "$profile"

# Plain Arch only, whatever the build computer runs: Arch's own mirrors, and
# a download folder of the build's own. So a package from another distro
# (say CachyOS's mpvpaper, same file name as ours) is never even looked at.
cat > "$WORK/mirrorlist" <<'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://fastly.mirror.pkgbuild.com/$repo/os/$arch
EOF
mkdir -p "$WORK/pkg-cache"
# Signatures are checked against a keyring of the build's own: Arch's keys
# plus the ZeXOS key (packaging/zexos-keyring), never the build computer's
# keyring, which may trust other distros' keys.
GPGDIR="$WORK/gnupg"
rm -rf "$GPGDIR"
pacman-key --gpgdir "$GPGDIR" --init >/dev/null 2>&1
pacman-key --gpgdir "$GPGDIR" --populate archlinux >/dev/null 2>&1
pacman-key --gpgdir "$GPGDIR" --add "$here/../packaging/zexos-keyring/zexos.gpg" >/dev/null 2>&1
while IFS=: read -r fpr _; do
    [ -n "$fpr" ] && pacman-key --gpgdir "$GPGDIR" --lsign-key "$fpr" >/dev/null 2>&1
done < "$here/../packaging/zexos-keyring/zexos-trusted"
sed -i -e "s|^Include = /etc/pacman.d/mirrorlist|Include = $WORK/mirrorlist|" \
    -e "s|^#CacheDir .*|CacheDir = $WORK/pkg-cache/|" \
    -e "s|^#GPGDir .*|GPGDir = $GPGDIR/|" "$profile/pacman.conf"

# Files: common ones first, then the window installer's, then the text one's.
for part in common gui tui; do
    [ -d "$here/$part/airootfs" ] && cp -a "$here/$part/airootfs/." "$profile/airootfs/"
    [ -f "$here/$part/packages.x86_64" ] && cat "$here/$part/packages.x86_64" >> "$profile/packages.x86_64"
    [ -f "$here/$part/pacman.conf.append" ] && cat "$here/$part/pacman.conf.append" >> "$profile/pacman.conf"
    if [ -f "$here/$part/permissions" ]; then
        { echo "file_permissions+=("; cat "$here/$part/permissions"; echo ")"; } >> "$profile/profiledef.sh"
    fi
    [ -x "$here/$part/customize.sh" ] && "$here/$part/customize.sh" "$profile"
done

# Each package once (several parts need git, the ZeXOS keyring, ...).
awk '/^[[:space:]]*(#|$)/ || !seen[$1]++' "$profile/packages.x86_64" > "$profile/packages.x86_64.new"
mv "$profile/packages.x86_64.new" "$profile/packages.x86_64"

# Nothing on the ISO may point at this build computer's folders.
if grep -rlF "$WORK" "$profile/airootfs"; then
    echo "The files above point at $WORK, which only exists on this computer." >&2
    exit 1
fi

echo "ZEXOS_BRANCH=$BRANCH" > "$profile/airootfs/etc/zexos-iso.conf"

# The live system is called ZeXOS too, not Arch. /etc/os-release belongs to
# no package, so packages installed later in the build leave it alone.
sh "$here/common/airootfs/usr/local/share/zexos/branding/zexos-branding" "$profile/airootfs"

# Name it ZeXOS instead of Arch Linux: file name, volume label, boot menu.
sed -i \
    -e "s|^iso_name=.*|iso_name=\"zexos\"|" \
    -e "s|^iso_label=.*|iso_label=\"ZEXOS_\$(date --date=\"@\${SOURCE_DATE_EPOCH:-\$(date +%s)}\" +%Y%m)\"|" \
    -e "s|^iso_publisher=.*|iso_publisher=\"ZeXOS <https://github.com/zefuros1991/ZeXOS>\"|" \
    -e "s|^iso_application=.*|iso_application=\"ZeXOS installer\"|" \
    "$profile/profiledef.sh"
grep -rl "Arch Linux install medium" "$profile/efiboot" "$profile/syslinux" "$profile/grub" 2>/dev/null \
    | xargs -r sed -i "s/Arch Linux install medium/ZeXOS (window installer)/g"

# Packing the live system is most of the build time. Test ISOs (any branch
# but main) use zstd: several times faster to make, a somewhat bigger file.
# Release ISOs keep Arch's xz, the smallest download. ZEXOS_ISO_COMPRESS=
# fast|small picks one by hand.
COMPRESS="${ZEXOS_ISO_COMPRESS:-}"
[ -n "$COMPRESS" ] || { [ "$BRANCH" = main ] && COMPRESS=small || COMPRESS=fast; }
if [ "$COMPRESS" = fast ]; then
    sed -i "s|^airootfs_image_tool_options=.*|airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6' '-b' '1M')|" \
        "$profile/profiledef.sh"
    sed -i -e 's|^COMPRESSION=.*|COMPRESSION="zstd"|' -e 's|^COMPRESSION_OPTIONS=.*|COMPRESSION_OPTIONS=(-T0 -6)|' \
        "$profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
fi
echo "Packing: $COMPRESS ($( [ "$COMPRESS" = fast ] && echo zstd || echo xz ))"

mkarchiso -v -r -w "$WORK/work-$variant" -o "$OUT" "$profile"
chown "$owner" "$OUT"/zexos-[0-9]*.iso
ls -lh "$OUT"/zexos-[0-9]*.iso
