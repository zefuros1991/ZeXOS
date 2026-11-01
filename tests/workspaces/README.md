# Workspace behaviour tests

Checks that workspaces behave **exactly like niri** on niri, Mango and
Hyprland. niri is the reference; its adapter must pass first.

    tests/workspaces/run.sh niri|mango|hyprland|all

Each scenario starts a throw-away copy of the compositor (nested in the
running desktop, or headless for Mango) with the repo's real config minus
autostart, opens tiny test windows (`wl-window.c`) and drives it with the
same actions the keys and scroll wheel are bound to.

State is printed as the number of windows on each workspace, in order,
`*` = focused: `1 0* 1 0` means ws 2 is empty and focused, ws 3 has a window,
ws 4 is the empty one at the end.

Rules (niri):
- There is always exactly one empty workspace at the end.
- An empty workspace in the middle disappears once you leave it, the ones
  after it move up.
- Going or moving past the end lands on the empty one at the end. Going or
  moving up from workspace 1 does nothing (no wrap).
- Moving a window takes focus along.
