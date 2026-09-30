-- Your screens
--
-- This line lets Hyprland pick the best mode for every screen by itself.
-- Example, a laptop screen at 120 Hz, drawn 25% bigger:
--   hl.monitor({ output = "eDP-1", mode = "2560x1600@120", position = "0x0", scale = 1.25 })
-- `hyprctl monitors` lists the names of your screens.
-- More: https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
