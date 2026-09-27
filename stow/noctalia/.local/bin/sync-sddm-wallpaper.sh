#!/bin/sh
# Called by noctalia's wallpaper hook (v4: $1=path; v5: $NOCTALIA_WALLPAPER_PATH)
# Mirrors the active wallpaper into the SDDM (pixie theme) login background.
set -eu

SRC="${1:-${NOCTALIA_WALLPAPER_PATH:-}}"  # v4 passed it as $1, v5 sets NOCTALIA_WALLPAPER_PATH
DEST="/var/lib/sddm-wallpaper/current.jpg"

[ -f "$SRC" ] || exit 0

magick "$SRC" -resize 1920x1080^ -gravity center -extent 1920x1080 -quality 85 "$DEST.tmp"
mv "$DEST.tmp" "$DEST"
