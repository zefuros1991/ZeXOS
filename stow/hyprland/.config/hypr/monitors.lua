-- Your screens
--
-- This line lets Hyprland pick the best mode for every screen, drawn at
-- normal size (scale 1, same as Mango). Hyprland's own "auto" scale jumps
-- straight to 1.5 on a common 15.6" 1080p laptop, which looks enormous.
-- Example, a laptop screen at 120 Hz, drawn 25% bigger:
--   hl.monitor({ output = "eDP-1", mode = "2560x1600@120", position = "0x0", scale = 1.25 })
-- `hyprctl monitors` lists the names of your screens.
-- More: https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
