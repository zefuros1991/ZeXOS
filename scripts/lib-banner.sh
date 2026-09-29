#!/usr/bin/env bash
# The ZeXOS banner every install step opens with: the logo painted in the
# colours of docs/logo/zexos-mark.svg (violet -> purple -> green, running
# diagonally like in the SVG), and the info text under it in violet.
#
# install.sh has its own copy of this, because on a first install it is
# downloaded on its own and the repo isn't there yet. Change both together.
#
# Terminals that can't show exact colours (the Linux console, some old
# ones) get the nearest basic colours instead: blue, magenta, green.

ZEXOS_BANNER_ROWS=(
'█████████╗            ███╗   ████╗   ████████╗  ████████╗'
'╚════███╔╝            ╚███╗  ╚═══╝  ██╔═════██╗██╔══════╝'
'    ███╔╝  ██████╗     ╚███╗        ██║     ██║██║       '
'   ███╔╝  ██╔═══██╗     ╚███╗       ██║     ██║╚███████╗ '
'  ███╔╝   ████████║      ╚███╗      ██║     ██║ ╚═════██╗'
' ███╔╝    ██╔═════╝       ╚███╗     ██║     ██║       ██║'
'█████████╗╚███████╗ ████╗  ╚███╗    ╚████████╔╝████████╔╝'
'╚════════╝ ╚══════╝ ╚═══╝   ╚══╝     ╚═══════╝ ╚═══════╝ '
)

case "$COLORTERM" in
    truecolor|24bit) ZEXOS_TRUECOLOR=1 ;;
    *) ZEXOS_TRUECOLOR=0 ;;
esac

if [ "$ZEXOS_TRUECOLOR" = 1 ]; then
    VIOLET=$'\e[38;2;154;92;242m'
else
    VIOLET=$'\e[95m'
fi

# Colour for a place along the logo, 0 (top left, violet) to 32 (bottom
# right, green). The three stops are the SVG's own: #7C5CFF, #B45CE6, #3DDC97.
zexos_banner_colour() {
    local s=$1 a b t
    if [ "$ZEXOS_TRUECOLOR" != 1 ]; then
        if [ "$s" -lt 11 ]; then REPLY=$'\e[94m'
        elif [ "$s" -lt 22 ]; then REPLY=$'\e[95m'
        else REPLY=$'\e[92m'; fi
        return
    fi
    if [ "$s" -le 16 ]; then a=(124 92 255); b=(180 92 230); t=$s
    else a=(180 92 230); b=(61 220 151); t=$((s - 16)); fi
    REPLY=$'\e[38;2;'"$(( a[0] + (b[0] - a[0]) * t / 16 ));$(( a[1] + (b[1] - a[1]) * t / 16 ));$(( a[2] + (b[2] - a[2]) * t / 16 ))m"
}

# One logo row with its colours, in REPLY.
zexos_banner_row() {
    local LC_ALL=C.UTF-8
    local row=${ZEXOS_BANNER_ROWS[$1]} out="" i ch
    for (( i = 0; i < ${#row}; i++ )); do
        ch=${row:i:1}
        if [ "$ch" = " " ]; then out+=" "; continue; fi
        zexos_banner_colour $(( (i + 2 * $1) * 32 / 72 ))
        out+="$REPLY$ch"
    done
    REPLY="$out"$'\e[0m'
}

# The logo with a blank line above and below, then TITLE and a line in violet.
zexos_banner() {
    local r
    echo
    for r in "${!ZEXOS_BANNER_ROWS[@]}"; do
        zexos_banner_row "$r"
        printf '%s\n' "$REPLY"
    done
    echo
    printf '%s        %s\n' "$VIOLET" "$1"
    printf '%s\e[0m\n' "--------------------------------------------------"
}
