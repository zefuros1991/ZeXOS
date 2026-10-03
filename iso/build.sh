#!/usr/bin/env bash
# Builds a ZeXOS installer ISO on top of Arch's own live ISO profile
# (releng, from the archiso package).
#
#   sudo ./iso/build.sh tui        text installer (archinstall + ZeXOS)
#   sudo ./iso/build.sh gui        graphical installer (Calamares on niri)
#
# Both are online installers: they download Arch and ZeXOS while installing.
#
# Settings (environment):
#   ZEXOS_BRANCH   branch the ISO installs (default main; beta for testing)
#   ZEXOS_ISO_OUT  where the .iso goes          (default ./out)
#   ZEXOS_ISO_WORK scratch space, several GB    (default /var/tmp/zexos-iso)
#   ZEXOS_CALAMARES_REPO  gui only: folder with the zexos-calamares package
#                  and its zexos-iso.db (see iso/README.md)
set -euo pipefail

variant="${1:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$variant" in
    tui|gui) ;;
    *) echo "usage: sudo $0 tui|gui" >&2; exit 1 ;;
esac
if [ "$(id -u)" -ne 0 ]; then
    echo "mkarchiso needs root: run this with sudo." >&2
    exit 1
fi
command -v mkarchiso >/dev/null || { echo "Install archiso first: sudo pacman -S archiso" >&2; exit 1; }

BRANCH="${ZEXOS_BRANCH:-main}"
OUT="${ZEXOS_ISO_OUT:-$PWD/out}"
WORK="${ZEXOS_ISO_WORK:-/var/tmp/zexos-iso}"
profile="$WORK/profile-$variant"

rm -rf "$profile" "$WORK/work-$variant"
mkdir -p "$WORK" "$OUT"
cp -a /usr/share/archiso/configs/releng "$profile"

# Files: common ones first, then the variant's own.
for part in common "$variant"; do
    [ -d "$here/$part/airootfs" ] && cp -a "$here/$part/airootfs/." "$profile/airootfs/"
    [ -f "$here/$part/packages.x86_64" ] && cat "$here/$part/packages.x86_64" >> "$profile/packages.x86_64"
    [ -f "$here/$part/pacman.conf.append" ] && cat "$here/$part/pacman.conf.append" >> "$profile/pacman.conf"
    [ -f "$here/$part/zlogin.append" ] && cat "$here/$part/zlogin.append" >> "$profile/airootfs/root/.zlogin"
    if [ -f "$here/$part/permissions" ]; then
        { echo "file_permissions+=("; cat "$here/$part/permissions"; echo ")"; } >> "$profile/profiledef.sh"
    fi
    [ -x "$here/$part/customize.sh" ] && "$here/$part/customize.sh" "$profile"
done

echo "ZEXOS_BRANCH=$BRANCH" > "$profile/airootfs/etc/zexos-iso.conf"

# Name it ZeXOS instead of Arch Linux: file name, volume label, boot menu.
sed -i \
    -e "s|^iso_name=.*|iso_name=\"zexos-$variant\"|" \
    -e "s|^iso_label=.*|iso_label=\"ZEXOS_\$(date --date=\"@\${SOURCE_DATE_EPOCH:-\$(date +%s)}\" +%Y%m)\"|" \
    -e "s|^iso_publisher=.*|iso_publisher=\"ZeXOS <https://github.com/zefuros1991/ZeXOS>\"|" \
    -e "s|^iso_application=.*|iso_application=\"ZeXOS installer ($variant)\"|" \
    "$profile/profiledef.sh"
grep -rl "Arch Linux install medium" "$profile/efiboot" "$profile/syslinux" "$profile/grub" 2>/dev/null \
    | xargs -r sed -i "s/Arch Linux install medium/ZeXOS installer ($variant)/g"

mkarchiso -v -r -w "$WORK/work-$variant" -o "$OUT" "$profile"
ls -lh "$OUT"/zexos-"$variant"-*.iso
