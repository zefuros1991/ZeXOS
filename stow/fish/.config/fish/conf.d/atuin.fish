# Atuin -- searchable, timestamped shell history (idea #20 from the
# 2026-07-17 top-20 sweep). Package-only install done earlier tonight;
# this wires the actual fish shell integration + history import.
#
# DECISION ITEMS -- deliberately left at atuin's SAFE (non-default)
# behavior below. Atuin's own defaults silently take over three bindings
# that change existing muscle memory / behavior:
#   1. Ctrl-R  -> atuin's fuzzy search (instead of fish's own reverse
#      search)
#   2. Up-arrow -> atuin's search-as-you-type-through-history (instead
#      of fish's normal "recall previous command" up-arrow)
#   3. `?` typed at an EMPTY prompt -> Atuin AI natural-language mode
#      (calls out to an AI backend -- a new network/privacy surface
#      nobody explicitly asked for)
# None of the three are enabled here. Atuin's history recording, import,
# and the `atuin search`/`atuin history` CLI commands all work regardless
# -- only the automatic keybind takeover is disabled. Ask the user which
# (if any) of the three they actually want before flipping these:
#   - remove `--disable-ctrl-r`   to let atuin take Ctrl-R
#   - remove `--disable-up-arrow` to let atuin take the up arrow
#   - remove `--disable-ai`       to enable the `?` AI trigger
# A non-conflicting alternative bind (e.g. a manual `bind` line on a
# different key) is also possible instead of taking over Ctrl-R/up-arrow
# -- worth asking the user which they'd prefer rather than picking for
# them.

if status is-interactive; and command -v atuin >/dev/null
    atuin init fish --disable-ctrl-r --disable-up-arrow --disable-ai | source
end
