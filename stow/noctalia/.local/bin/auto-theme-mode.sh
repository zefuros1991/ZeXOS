#!/bin/sh
# Switch between dark and light mode to suit the wallpaper.
# Noctalia runs this every time the wallpaper changes and gives the picture
# in $NOCTALIA_WALLPAPER_PATH. A very bright wallpaper (mostly white) gets
# light mode with grey-scale colours (a white picture has no colour to take,
# so the usual colour-picking would grab a stray speck of it); any other
# wallpaper gets dark mode with ZeXOS's normal "faithful" colours.
# If you picked another colour style yourself, only the mode is switched.
#
# To choose the mode yourself instead, create ~/.config/zexos/manual-theme-mode
# and set it in Noctalia's settings as usual.
set -eu

picture="${1:-${NOCTALIA_WALLPAPER_PATH:-}}"

# How bright the picture must be for light mode, from 0 (black) to 1 (white).
# The ZeXOS wallpapers score 0.08-0.22, a mostly white one about 0.95.
threshold=0.6

[ -f "$picture" ] || exit 0
[ -e "${XDG_CONFIG_HOME:-$HOME/.config}/zexos/manual-theme-mode" ] && exit 0

# Average brightness: shrink the picture, turn it grey, take the mean.
brightness=$(magick "$picture" -resize 64x64! -colorspace Gray -format '%[fx:mean]' info:)

if awk -v b="$brightness" -v t="$threshold" 'BEGIN { exit !(b >= t) }'; then
    want=light
    scheme=m3-monochrome
else
    want=dark
    scheme=faithful
fi

# Colour style first, so the mode switch below redraws with it.
case "$(noctalia msg color-scheme-get 2>/dev/null)" in
    "wallpaper faithful"|"wallpaper m3-monochrome")
        if [ "$(noctalia msg color-scheme-get)" != "wallpaper $scheme" ]; then
            noctalia msg color-scheme-set wallpaper "$scheme"
        fi ;;
esac

# Only switch when needed: each switch redraws the whole theme.
if [ "$(noctalia msg theme-mode-get 2>/dev/null)" != "$want" ]; then
    noctalia msg theme-mode-set "$want"
fi
