# Scenarios. Expectations are what niri does (measured on niri 26.04).

s_fresh() {
    expect "fresh: one empty workspace" "0*"
    ws_open a1
    expect "window on ws1 makes ws2 available" "1* 0"
}

s_build() {
    build3
    expect "three workspaces with windows + one empty at the end" "1 1 1* 0"
}

s_close_middle() {
    build3
    ws_goto 2; ws_close_focused
    expect_now "emptied ws2 stays while you are on it" "1 0* 1 0"
    ws_goto 1
    expect "after leaving, the empty ws2 is gone and ws3 became ws2" "1* 1 0"
    ws_goto 3
    expect "ws3 is now the empty one at the end" "1 1 0*"
}

s_close_middle_goto3() {
    build3
    ws_goto 2; ws_close_focused
    settle
    ws_goto 3
    expect "going to ws3 from the empty ws2 lands on the windows, ws2 closes" "1 1* 0"
}

s_close_first() {
    build3
    ws_goto 1; ws_close_focused
    ws_goto 3
    expect "closing ws1 shifts everything up" "1 1* 0"
}

s_no_wrap_up() {
    build3
    ws_goto 1; ws_prev; ws_prev
    expect "scroll up from ws1 stays on ws1 (no wrap)" "1* 1 1 0"
}

s_next_stops() {
    build3
    ws_next
    expect "next from the last window workspace goes to the empty one" "1 1 1 0*"
    ws_next; ws_next; ws_next
    expect "next again stays on the empty one" "1 1 1 0*"
}

s_next_steps() {
    build3
    ws_goto 1; ws_next
    expect "scroll down from ws1 goes to ws2 (not 3)" "1 1* 1 0"
    ws_next
    expect "scroll down again goes to ws3" "1 1 1* 0"
}

s_goto_clamp() {
    build3
    ws_goto 1; ws_goto 9
    expect "Mod+9 with 3 workspaces lands on the empty one at the end" "1 1 1 0*"
    ws_goto 2
    expect "Mod+2 goes to ws2" "1 1* 1 0"
}

s_goto_empty_fresh() {
    ws_open a1
    ws_goto 5
    expect "Mod+5 with 1 workspace in use lands on ws2, the empty one" "1 0*"
}

s_move_n() {
    ws_open a1; ws_open a2
    ws_move 2
    expect "Mod+Ctrl+2 takes the window to ws2, focus follows" "1 1* 0"
    ws_move 9
    expect "Mod+Ctrl+9 clamps to the end; the emptied ws2 closes" "1 1* 0"
}

s_move_next() {
    ws_open a1; ws_open a2
    ws_move_next
    expect "move to next workspace: window and focus go to ws2" "1 1* 0"
    ws_move_next
    expect "move to next again: ws2 empties and closes, window on new ws2" "1 1* 0"
}

s_move_prev() {
    ws_open a1; ws_open a2
    ws_move_next
    ws_move_prev
    expect "move back to previous workspace" "2* 0"
    ws_move_prev
    expect "move up from ws1 does nothing (no wrap)" "2* 0"
}

s_move_over_windows() {
    build3
    ws_goto 1; ws_move_next
    expect "moving the only window of ws1 down joins ws2, ws1 closes" "2* 1 0"
}

s_move_clamp_end() {
    build3
    ws_goto 1; ws_move 9
    expect "move far past the end: window lands last, ws1 closes, focus follows" "1 1 1* 0"
}

s_gesture() {
    build3
    ws_goto 1; ws_gesture_prev
    expect "3-finger down from ws1 stays (no wrap)" "1* 1 1 0"
    ws_gesture_next
    expect "3-finger up goes to ws2" "1 1* 1 0"
    ws_gesture_next; ws_gesture_next
    expect "3-finger up reaches the empty one at the end and stops" "1 1 1 0*"
    ws_gesture_prev
    expect "3-finger down goes back to ws3" "1 1 1* 0"
}

SCENARIOS="s_gesture s_fresh s_build s_close_middle s_close_middle_goto3 s_close_first s_no_wrap_up s_next_stops s_next_steps s_goto_clamp s_goto_empty_fresh s_move_n s_move_next s_move_prev s_move_over_windows s_move_clamp_end"
