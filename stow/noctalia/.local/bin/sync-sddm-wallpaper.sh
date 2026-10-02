#!/bin/sh
# Copy the desktop wallpaper to the login screen, so both match, and give the
# login avatar the wallpaper's colours.
# Noctalia runs this every time the wallpaper changes. It gives the picture
# as the first argument (Noctalia 4) or in $NOCTALIA_WALLPAPER_PATH (Noctalia 5).
# DMS (zexos-dms-sync) and a shell switch (zshell switch) run it too.
set -eu

picture="${1:-${NOCTALIA_WALLPAPER_PATH:-}}"
dir="/var/lib/sddm-wallpaper"                  # the Pixie login theme reads this
target="$dir/current.jpg"
avatars="/usr/share/sddm/themes/pixie/assets/avatars"   # from pixie-sddm-zexos

# Nothing to do if there's no picture.
[ -f "$picture" ] || exit 0

# Fill a 1920x1080 frame (crop the edges if needed), write to a temp file,
# then swap it in, so the login screen never sees a half-written image.
magick "$picture" -resize 1920x1080^ -gravity center -extent 1920x1080 -quality 85 "$target.tmp"
mv "$target.tmp" "$target"

# Which avatar fits: violet, ocean, ember, forest, mono or light (the colour
# sets of the ZeXOS wallpapers). A ZeXOS wallpaper says it in its name
# (zexos-aurora-ocean.jpg; no colour in the name means violet). This also
# works for a video's first frame, whose name holds the video's name.
family() {
    case "$(basename "$1" | tr 'A-Z' 'a-z')" in
        *zexos-*-ocean.*)  echo ocean ;;
        *zexos-*-ember.*)  echo ember ;;
        *zexos-*-forest.*) echo forest ;;
        *zexos-*-mono.*)   echo mono ;;
        *zexos-*-light.*)  echo light ;;
        *zexos-*)          echo violet ;;
        *) guess "$1" ;;
    esac
}

# Any other picture: look at its colours. Bright overall means light, almost
# no colour means mono. Otherwise take the hue of its colourful parts
# (stronger colours count more) and pick the nearest colour set.
guess() {
    magick "$1" -resize 48x48! -depth 8 txt:- 2>/dev/null | awk '
        /^[0-9]/ {
            if (!match($0, /\([0-9.]+,[0-9.]+,[0-9.]+/)) next
            split(substr($0, RSTART + 1, RLENGTH - 1), c, ",")
            r = c[1] / 255; g = c[2] / 255; b = c[3] / 255
            mx = r; if (g > mx) mx = g; if (b > mx) mx = b
            mn = r; if (g < mn) mn = g; if (b < mn) mn = b
            n++; grey += (r + g + b) / 3
            ch = mx - mn
            if (ch < 0.04) next
            if (mx == r)      h = (g - b) / ch
            else if (mx == g) h = (b - r) / ch + 2
            else              h = (r - g) / ch + 4
            h = h * 3.14159265 / 3
            x += ch * cos(h); y += ch * sin(h); w += ch
        }
        END {
            if (n == 0) { print "violet"; exit }
            if (grey / n >= 0.6) { print "light"; exit }
            if (w / n < 0.015) { print "mono"; exit }
            h = atan2(y, x) * 180 / 3.14159265; if (h < 0) h += 360
            if (h >= 60 && h < 170)       print "forest"
            else if (h >= 170 && h < 232) print "ocean"
            else if (h >= 232 && h < 320) print "violet"
            else                          print "ember"
        }'
}

# Copy the avatar next to the login wallpaper (Pixie's avatar.jpg is a link
# to it), the same temp-file way. Skipped if the avatars aren't installed.
fam="$(family "$picture")"
[ -n "$fam" ] || fam=violet
if [ -f "$avatars/$fam.jpg" ]; then
    cp "$avatars/$fam.jpg" "$dir/avatar.jpg.tmp"
    mv "$dir/avatar.jpg.tmp" "$dir/avatar.jpg"
fi
