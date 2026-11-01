# niri adapter: a nested niri with the repo's real config (no autostart).
NIRI_SRC=$REPO/stow/niri/.config/niri

ws_start() {
    T=$(mktemp -d "${TMPDIR:-/tmp}/wstest-niri.XXXXXX")
    cp -r "$NIRI_SRC" "$T/niri"; : > "$T/niri/cfg/autostart.kdl"
    ( cd "$T" && exec niri -c niri/config.kdl >"$T/niri.log" 2>&1 ) &
    NIRI_PID=$!
    local i
    for i in $(seq 50); do
        grep -q 'IPC listening' "$T/niri.log" 2>/dev/null && break; sleep 0.2
    done
    WD=$(sed 's/\x1b\[[0-9;]*m//g' "$T/niri.log" | sed -n 's/.*listening on Wayland socket: //p' | head -1)
    export NIRI_SOCKET=$(sed 's/\x1b\[[0-9;]*m//g' "$T/niri.log" | sed -n 's/.*IPC listening on: //p' | head -1)
    [[ -S $NIRI_SOCKET && -n $WD ]] || { cat "$T/niri.log"; return 1; }
    hide_nested niri
    sleep 1
}

ws_stop() {
    pkill -P $$ -x wl-window 2>/dev/null
    kill "$NIRI_PID" 2>/dev/null; wait "$NIRI_PID" 2>/dev/null
    rm -rf "$T"
}

_act() { niri msg action "$@" >/dev/null; }
ws_open() { open_window "$WD" "$1"; }
ws_close_focused() { _act close-window; }
ws_goto() { _act focus-workspace "$1"; }
ws_next() { _act focus-workspace-down; }
ws_prev() { _act focus-workspace-up; }
ws_move() { _act move-column-to-workspace "$1"; }
ws_move_next() { _act move-column-to-workspace-down; }
ws_move_prev() { _act move-column-to-workspace-up; }

ws_state() {
    local wss wins
    wss=$(niri msg -j workspaces); wins=$(niri msg -j windows)
    jq -nr --argjson w "$wss" --argjson c "$wins" '
        [$w | sort_by(.idx)[] | . as $x
         | ([$c[] | select(.workspace_id == $x.id)] | length | tostring)
           + (if $x.is_focused then "*" else "" end)] | join(" ")'
}

ws_check_bindings() { :; } # niri is the reference

ws_window_count() { niri msg -j windows | jq '[.[] | select(.app_id=="zexos-test")] | length'; }
