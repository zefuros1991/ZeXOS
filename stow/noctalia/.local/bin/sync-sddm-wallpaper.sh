#!/bin/sh
# Copy the desktop wallpaper to the login screen, so both match.
# Noctalia runs this every time the wallpaper changes. It gives the picture
# as the first argument (Noctalia 4) or in $NOCTALIA_WALLPAPER_PATH (Noctalia 5).
set -eu

picture="${1:-${NOCTALIA_WALLPAPER_PATH:-}}"
target="/var/lib/sddm-wallpaper/current.jpg"   # the Pixie login theme reads this

# Nothing to do if there's no picture.
[ -f "$picture" ] || exit 0

# Fill a 1920x1080 frame (crop the edges if needed), write to a temp file,
# then swap it in, so the login screen never sees a half-written image.
magick "$picture" -resize 1920x1080^ -gravity center -extent 1920x1080 -quality 85 "$target.tmp"
mv "$target.tmp" "$target"
