# Mango adapter: headless Mango with the repo's real config (no autostart).
# Actions run the command the real binding in keybinds.conf is set to, so a
# wrong or missing binding fails the scenarios.
MANGO_SRC=$REPO/stow/mango/.config/mango
MANGO_BIN=$REPO/stow/mango/.local/bin
SETTLE=${SETTLE:-0.6}

ws_start() {
    T=$(mktemp -d "${TMPDIR:-/tmp}/wstest-mango.XXXXXX")
    cp -r "$MANGO_SRC" "$T/mango"; : > "$T/mango/cfg/autostart.conf"
    rm -f "$T/mango/noctalia.conf" "$T/mango/vm.conf" "$T/mango/motion.conf"
    mkdir -p "$T/home"
    before=$(ls /run/user/$UID | grep -E '^wayland-[0-9]+$' | sort)
    ( cd "$T" && export HOME=$T/home PATH=$MANGO_BIN:$PATH && exec \
        env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE WLR_BACKENDS=headless WLR_RENDERER=pixman \
        WLR_LIBINPUT_NO_DEVICES=1 mango -c "$T/mango/config.conf" >"$T/mango.log" 2>&1 ) &
    MANGO_PID=$!
    local i
    for i in $(seq 60); do
        MANGO_REAL=$(pgrep -nx mango)
        MANGO_INSTANCE_SIGNATURE=/run/user/$UID/mango-$MANGO_REAL.sock
        WD=$(comm -13 <(echo "$before") <(ls /run/user/$UID | grep -E '^wayland-[0-9]+$' | sort) | head -1)
        [[ -S $MANGO_INSTANCE_SIGNATURE && -n $WD ]] && break
        sleep 0.2
    done
    export MANGO_INSTANCE_SIGNATURE
    [[ -S $MANGO_INSTANCE_SIGNATURE && -n $WD ]] || { echo "sig=$MANGO_INSTANCE_SIGNATURE wd=$WD"; tail -5 "$T/mango.log"; return 1; }
    sleep 0.5
}

ws_stop() {
    pkill -P $$ -x wl-window 2>/dev/null
    kill "$MANGO_REAL" 2>/dev/null; wait "$MANGO_PID" 2>/dev/null
    sleep 0.3; kill -9 "$MANGO_REAL" 2>/dev/null
    rm -f "/run/user/$UID/mango-$MANGO_REAL.sock" "/run/user/$UID/$WD" "/run/user/$UID/$WD.lock"
    rm -rf "$T"
}

# _bound <kind> <mods,key>  -> the dispatch string of that binding
_bound() {
    awk -F= -v k="$1" -v m="$2" '$1==k { sub(/^[^=]*=/,""); if (index($0, m ",")==1) { print substr($0, length(m)+2); exit } }' \
        "$MANGO_SRC/cfg/keybinds.conf"
}
_run() { # kind mods,key
    local d; d=$(_bound "$1" "$2")
    [[ -n $d ]] || { echo "NO BINDING: $1=$2" >&2; return 1; }
    # spawn_shell/spawn run inside Mango (so they see the right socket)
    mmsg dispatch "$d" >/dev/null; sleep 0.5 # spawned scripts take a moment
}

ws_open() { open_window "$WD" "$1"; }
ws_close_focused() { mmsg dispatch killclient >/dev/null; }
ws_goto() { _run bind "SUPER,$1"; }
ws_next() { _run axisbind SUPER,DOWN; }
ws_prev() { _run axisbind SUPER,UP; }
ws_move() { _run bind "SUPER+CTRL,$1"; }
ws_move_next() { _run axisbind SUPER+CTRL,DOWN; }
ws_move_prev() { _run axisbind SUPER+CTRL,UP; }
ws_gesture_next() { _run gesturebind none,up,3; }
ws_gesture_prev() { _run gesturebind none,down,3; }

ws_window_count() { mmsg get all-clients | jq '[.clients[]?] | length' 2>/dev/null || echo 0; }

# windows per tag; trailing empty one + focused tag (the active one) shown
ws_state() {
    mmsg get all-monitors | jq -r '
        .monitors[] | select(.active) | . as $m | ($m.active_tags[0]) as $f
        | ([$m.tags[] | select(.client_count>0) | .index] | max // 0) as $last
        | ([$last + 1, $f] | max) as $n
        | [$m.tags[] | select(.index <= $n)
           | (.client_count|tostring) + (if .index==$f then "*" else "" end)] | join(" ")'
}

# Every binding the scenarios rely on must exist.
ws_check_bindings() {
    local n miss=0 b
    for n in 1 2 3 4 5 6 7 8 9; do
        for b in "bind SUPER,$n" "bind SUPER+CTRL,$n"; do
            [[ -n $(_bound $b) ]] || { echo "  FAIL  missing binding $b"; miss=1; }
        done
    done
    for b in "axisbind SUPER,UP" "axisbind SUPER,DOWN" "axisbind SUPER+CTRL,UP" "axisbind SUPER+CTRL,DOWN" \
             "gesturebind none,up,3" "gesturebind none,down,3"; do
        [[ -n $(_bound $b) ]] || { echo "  FAIL  missing binding $b"; miss=1; }
    done
    ((miss)) && { FAIL=$((FAIL+1)); FAILED+=("bindings missing"); } || { PASS=$((PASS+1)); echo "  ok    all bindings present"; }
}
