#!/usr/bin/env bash
# triage-bundle.sh — one-shot machine-specific quick-triage snapshot for this
# CachyOS/niri/hybrid-AMD-NVIDIA laptop. Dumps the standard first-look
# diagnostics for any troubleshooting session into one timestamped file
# under ~/AI/Triage/, instead of running the same 5-10 commands by hand
# every time.
#
# Idempotent / read-only: never modifies system state, safe to re-run any
# number of times. Some sections use `sudo -n` (non-interactive) and are
# skipped with a note if the sudo cache is cold — this script never
# triggers a password/polkit prompt.
#
# Usage: triage-bundle.sh [optional-label]
#   e.g. triage-bundle.sh "division2-choppy"

set -uo pipefail  # deliberately not -e: one failing section shouldn't kill the whole bundle

OUT_DIR="${HOME}/AI/Triage"
mkdir -p "$OUT_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
LABEL="${1:-}"
if [[ -n "$LABEL" ]]; then
  # sanitize label to something filename-safe
  LABEL="-$(echo "$LABEL" | tr -c 'a-zA-Z0-9_-' '-' | sed 's/-\+/-/g; s/^-//; s/-$//')"
fi
OUT_FILE="${OUT_DIR}/triage-${TS}${LABEL}.txt"

section() {
  echo ""
  echo "===================================================================="
  echo "== $1"
  echo "===================================================================="
}

{
  section "triage-bundle.sh run at $(date -Iseconds) on host $(hostname)"

  section "Kernel + scheduler"
  uname -a
  echo "--- sched_ext state ---"
  cat /sys/kernel/sched_ext/state 2>/dev/null || echo "(sched_ext not present in this kernel)"
  echo "--- scx.service / scx_loader.service ---"
  systemctl is-active scx.service scx_loader.service 2>&1 || true

  section "GPU MUX mode (asusctl armoury)"
  if command -v asusctl >/dev/null 2>&1; then
    asusctl armoury get gpu_mux_mode 2>&1 || echo "(asusctl call failed)"
  else
    echo "(asusctl not installed)"
  fi

  section "niri msg outputs"
  if command -v niri >/dev/null 2>&1; then
    niri msg outputs 2>&1 || echo "(niri msg outputs failed -- is niri the running compositor?)"
  else
    echo "(niri not installed)"
  fi

  section "journalctl -p err -b (this boot, errors and above)"
  journalctl -p err -b --no-pager -o short-iso 2>&1 | tail -200

  section "coredumpctl list (all recorded crashes)"
  coredumpctl list --no-pager 2>&1 | tail -50

  section "inxi -Fxxxz (full hardware/software summary, MAC/serial redacted)"
  if command -v inxi >/dev/null 2>&1; then
    inxi -Fxxxz 2>&1
  else
    echo "(inxi not installed)"
  fi

  section "pacman -Qu (pending upgrades) / arch-manwarn status"
  pacman -Qu 2>&1 | head -30 || echo "(none pending or pacman -Qu failed)"
  echo "--- arch-manwarn ---"
  if command -v arch-manwarn >/dev/null 2>&1; then
    if sudo -n true 2>/dev/null; then
      sudo -n arch-manwarn status 2>&1
    else
      echo "(sudo cache cold -- skipped to avoid a password prompt; run 'sudo arch-manwarn status' manually)"
    fi
  else
    echo "(arch-manwarn not installed)"
  fi

  section "Recent snapper snapshots (root)"
  if sudo -n true 2>/dev/null; then
    sudo -n snapper -c root list 2>&1 | tail -15
  else
    echo "(sudo cache cold -- skipped to avoid a password prompt; run 'sudo snapper -c root list' manually)"
  fi

  section "End of bundle"
  echo "Written to: $OUT_FILE"
} > "$OUT_FILE" 2>&1

echo "Triage bundle written: $OUT_FILE"
