#!/usr/bin/env bash
# Usage: run.sh niri|mango|hyprland|all [scenario ...]
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib.sh"
source "$HERE/scenarios.sh"
build_helper || { echo "cannot build wl-window"; exit 2; }

targets=${1:-all}; shift
[[ $targets == all ]] && targets="niri mango hyprland"
only=("$@")
rc=0
for t in $targets; do
    printf '\n######## %s\n' "$t"
    source "$HERE/adapters/$t.sh"
    PASS=0; FAIL=0; FAILED=()
    printf '\n== bindings\n'; CUR=bindings; ws_check_bindings
    for s in ${only[@]:-$SCENARIOS}; do scenario "$s" "$s"; done
    printf '\n%s: %d passed, %d failed\n' "$t" "$PASS" "$FAIL"
    ((FAIL)) && { printf '  - %s\n' "${FAILED[@]}"; rc=1; }
done
exit $rc
