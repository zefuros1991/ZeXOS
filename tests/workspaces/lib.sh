# Shared helpers for the workspace tests. Adapters (adapters/*.sh) define:
#   ws_start ws_stop ws_open ws_close_focused ws_goto N ws_next ws_prev
#   ws_move N ws_move_next ws_move_prev ws_state ws_check_bindings
# ws_state prints e.g. "1 0* 1 0" (windows per workspace, * = focused).

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
PASS=0; FAIL=0; FAILED=()
SETTLE=${SETTLE:-1.5}

settle() { sleep "$SETTLE"; }

# expect "<what>" "<expected state>" -- settles, then compares
expect() {
    local what=$1 want=$2 got
    settle
    got=$(ws_state)
    if [[ $got == "$want" ]]; then
        PASS=$((PASS+1)); printf '  ok    %s  [%s]\n' "$what" "$got"
    else
        FAIL=$((FAIL+1)); FAILED+=("$CUR: $what")
        printf '  FAIL  %s\n        want [%s]\n        got  [%s]\n' "$what" "$want" "$got"
    fi
}

# expect_now: no settle (for things that must hold immediately)
expect_now() {
    local what=$1 want=$2 got
    got=$(ws_state)
    if [[ $got == "$want" ]]; then
        PASS=$((PASS+1)); printf '  ok    %s  [%s]\n' "$what" "$got"
    else
        FAIL=$((FAIL+1)); FAILED+=("$CUR: $what")
        printf '  FAIL  %s\n        want [%s]\n        got  [%s]\n' "$what" "$want" "$got"
    fi
}

# Three workspaces with one window each, focus on the third.
build3() {
    ws_open a1; ws_next; ws_open b1; ws_next; ws_open c1
}

scenario() { # name function
    CUR=$1
    printf '\n== %s\n' "$1"
    ws_start || { FAIL=$((FAIL+1)); FAILED+=("$1: could not start"); return; }
    "$2"
    ws_stop
}

# Start a test window on a nested compositor's Wayland socket and wait for it.
open_window() { # socket title
    local before after i
    before=$(ws_window_count)
    WAYLAND_DISPLAY=$1 "$HERE/build/wl-window" "$2" >/dev/null 2>&1 &
    for i in $(seq 50); do
        after=$(ws_window_count); [[ $after -gt $before ]] && break; sleep 0.1
    done
    sleep 0.3
}

# Keep a nested compositor's window out of the way of the live desktop.
hide_nested() { # window class/title
    command -v hyprctl >/dev/null && [[ -n $HYPRLAND_INSTANCE_SIGNATURE ]] || return 0
    local i addr
    for i in $(seq 30); do
        addr=$(hyprctl clients -j | jq -r --arg t "$1" '.[] | select(.class==$t or .title==$t or (.title|test($t))) | .address' | head -1)
        [[ -n $addr ]] && break; sleep 0.2
    done
    [[ -n $addr ]] && hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:wstest\", window = \"address:$addr\" })" >/dev/null 2>&1
}

build_helper() {
    [[ -x $HERE/build/wl-window ]] && return 0
    mkdir -p "$HERE/build"
    local x=/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml
    wayland-scanner client-header "$x" "$HERE/build/xdg-shell-client-protocol.h"
    wayland-scanner private-code "$x" "$HERE/build/xdg-shell-protocol.c"
    gcc -O1 -I"$HERE/build" -o "$HERE/build/wl-window" "$HERE/wl-window.c" "$HERE/build/xdg-shell-protocol.c" \
        $(pkg-config --cflags --libs wayland-client)
}
