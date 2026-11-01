# Hyprland adapter: a nested Hyprland (inside the running desktop) with the
# repo's real config minus autostart. Workspace actions call the functions
# of cfg/workspaces.lua, the very ones the keys, the mouse wheel and the
# gesture are bound to; ws_check_bindings proves the bindings use them.
HYPR_SRC=$REPO/stow/hyprland/.config/hypr
SETTLE=${SETTLE:-1.0}
LIVE_SIG=$HYPRLAND_INSTANCE_SIGNATURE

ws_start() {
    T=$(mktemp -d "${TMPDIR:-/tmp}/wstest-hypr.XXXXXX")
    cp -r "$HYPR_SRC" "$T/hypr"; echo 'hl.on("hyprland.start", function() end)' > "$T/hypr/cfg/autostart.lua"
    rm -f "$T/hypr/noctalia.lua" "$T/hypr/shell-colors.lua" "$T/hypr/vm.lua" "$T/hypr/motion.lua"
    # a plain 1280x800 screen; the repo's monitors.lua is about docking
    echo 'hl.monitor({ output = "", mode = "1280x800@60", position = "auto", scale = 1 })' > "$T/hypr/monitors.lua"
    local before; before=$(hyprctl instances -j | jq -r '.[].instance' | sort)
    ( cd "$T" && exec Hyprland -c "$T/hypr/hyprland.lua" >"$T/hypr.log" 2>&1 ) &
    HYPR_PID=$!
    local i
    for i in $(seq 60); do
        SIG=$(comm -13 <(echo "$before") <(hyprctl instances -j | jq -r '.[].instance' | sort) | head -1)
        [[ -n $SIG ]] && hyprctl -i "$SIG" monitors -j 2>/dev/null | jq -e 'length>0' >/dev/null 2>&1 && break
        sleep 0.3
    done
    [[ -n $SIG ]] || { tail -20 "$T/hypr.log"; return 1; }
    WD=$(hyprctl instances -j | jq -r --arg s "$SIG" '.[] | select(.instance==$s) | .wl_socket')
    sleep 0.5
    # hide the nested window in the live desktop
    HYPRLAND_INSTANCE_SIGNATURE=$LIVE_SIG hide_nested aquamarine
    sleep 0.5
}

ws_stop() {
    pkill -P $$ -x wl-window 2>/dev/null
    hyprctl -i "$SIG" dispatch 'hl.dsp.exit()' >/dev/null 2>&1; sleep 0.5
    kill "$HYPR_PID" 2>/dev/null; wait "$HYPR_PID" 2>/dev/null
    rm -rf "$T"
}

_h() { hyprctl -i "$SIG" "$@"; }
_ws() { _h eval "require('cfg.workspaces').$1" >/dev/null; }

ws_open() { open_window "$WD" "$1"; }
ws_close_focused() { _h dispatch 'hl.dsp.window.close()' >/dev/null; }
ws_goto() { _ws "goto($1)"; }
ws_next() { _ws "next()"; }
ws_prev() { _ws "prev()"; }
ws_move() { _ws "move($1)"; }
ws_move_next() { _ws "move_next()"; }
ws_move_prev() { _ws "move_prev()"; }
ws_gesture_next() { _ws "next()"; }   # the gesture is bound to the same functions
ws_gesture_prev() { _ws "prev()"; }

ws_window_count() { _h clients -j | jq '[.[] | select(.class=="zexos-test")] | length'; }

ws_state() {
    local wss act cl
    wss=$(_h workspaces -j); act=$(_h activeworkspace -j | jq .id); cl=$(_h clients -j)
    jq -nr --argjson w "$wss" --argjson f "$act" --argjson c "$cl" '
        ([$w[] | select(.id > 0 and .windows > 0) | .id] | max // 0) as $last
        | ([$last + 1, $f] | max) as $n
        | [range(1; $n + 1) as $i
           | (([$w[] | select(.id == $i) | .windows] | first // 0) | tostring)
             + (if $i == $f then "*" else "" end)] | join(" ")'
}

# Every key, wheel turn and gesture must go through cfg/workspaces.lua.
ws_check_bindings() {
    local keys=() n b miss=0
    for n in 1 2 3 4 5 6 7 8 9; do keys+=("SUPER + $n" "SUPER + CTRL + $n"); done
    keys+=("SUPER + mouse_up" "SUPER + mouse_down" "SUPER + CTRL + mouse_up" "SUPER + CTRL + mouse_down")
    for b in "${keys[@]}"; do
        awk -v k="hl.bind(\"$b\"" 'index($0,k)==1{f=1;print;next} /^hl\.bind\(|^-- ===/{f=0} f' \
            "$HYPR_SRC/cfg/keybinds.lua" | grep -q 'wsm\.' || { echo "  FAIL  binding not using cfg.workspaces (wsm.): $b"; miss=1; }
    done
    grep -q 'wsm\.' "$HYPR_SRC/cfg/input.lua" || { echo "  FAIL  3-finger gesture not using cfg.workspaces"; miss=1; }
    ((miss)) && { FAIL=$((FAIL+1)); FAILED+=("bindings not using cfg.workspaces"); } || { PASS=$((PASS+1)); echo "  ok    all bindings use cfg.workspaces"; }
}
