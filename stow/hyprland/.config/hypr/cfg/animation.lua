-- How things move
--
-- Hyprland's own animations, which are already smooth, with one change:
-- the desktop shell's own pieces (bar, panels, pop-ups) don't slide in.
-- Noctalia's docs ask for this; the shell animates them itself.
-- More: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

hl.animation({ leaf = "layers", enabled = false })
