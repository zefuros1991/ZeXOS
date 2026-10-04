#!/usr/bin/env bash
# Run by iso/build.sh with the profile folder as $1, after the GUI files
# were copied in. Fills in what is generated rather than kept in git.
set -euo pipefail
profile="${1:?}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
air="$profile/airootfs"
brand="$air/etc/calamares/branding/zexos"

# zexos-calamares is not in any online repo yet: build it from
# iso/gui/calamares-pkg (makepkg), put it in a local repo (repo-add) and
# point ZEXOS_CALAMARES_REPO at that folder.
local_repo="${ZEXOS_CALAMARES_REPO:-}"
if [ -z "$local_repo" ] || [ ! -f "$local_repo/zexos-iso.db" ]; then
    echo "Set ZEXOS_CALAMARES_REPO to a folder with zexos-iso.db (see iso/README.md)." >&2
    exit 1
fi
sed -i "s|@LOCALREPO@|$local_repo|" "$profile/pacman.conf"

# The installed system gets plain Arch: same pacman.conf minus the
# live-only repos.
mkdir -p "$air/etc/zexos"
sed '/^# ZEXOS-LIVE-ONLY/,$d' "$profile/pacman.conf" > "$air/etc/zexos/pacman-arch.conf"

# Wallpaper for the live desktop, and backdrops for the install slideshow.
mkdir -p "$air/usr/share/zexos" "$brand/slides" "$brand/previews"
small() { magick "$1" -resize 1920x1080 -quality 85 "$2"; }
small "$repo/wallpapers/zexos-aurora.jpg" "$air/usr/share/zexos/wallpaper.jpg"
i=1
for w in aurora topo-energy dots-forest bars-ocean mark-ember aurora-ocean; do
    small "$repo/wallpapers/zexos-$w.jpg" "$brand/slides/$i.jpg"
    i=$((i + 1))
done

# Logo and icon.
rsvg-convert -w 256 -h 256 "$repo/docs/logo/zexos-mark.svg" -o "$brand/logo.png"
rsvg-convert -w 64 -h 64 "$repo/docs/logo/zexos-mark.svg" -o "$brand/icon.png"
rsvg-convert -w 640 "$repo/docs/logo/zexos-logo-dark.svg" -o "$brand/welcome.png"

# Picker previews: recorded clips live in iso/gui/previews/<id>.webp. Until
# one is recorded, a still placeholder stands in for it.
for id in niri hyprland mango noctalia dms; do
    clip="$repo/iso/gui/previews/$id.webp"
    if [ -f "$clip" ]; then
        cp "$clip" "$brand/previews/$id.webp"
    else
        magick "$repo/wallpapers/zexos-mark.jpg" -resize 960x540^ -gravity center -extent 960x540 \
            -fill '#0f0f14b0' -draw 'rectangle 0,380 960,540' \
            -fill '#e6e6ef' -font DejaVu-Sans-Bold -pointsize 42 -gravity south -annotate +0+80 "$id" \
            -fill '#9a9ab0' -font DejaVu-Sans -pointsize 22 -annotate +0+40 "preview coming soon" \
            "$brand/previews/$id.webp"
    fi
done
