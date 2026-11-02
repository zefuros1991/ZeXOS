-- How things move
--
-- ZeXOS defaults, the same as niri and Mango: windows zoom in from 80% and out on close,
-- workspaces slide with a small bounce. The
-- shell's bar and panels are left to the shell (Noctalia's docs ask for this).
-- To pick another style run `zexos-motion` (it writes ../motion.lua, loaded after this).
-- More: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

hl.curve("zx_open",  { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.curve("zx_close", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.curve("zx_pace",  { type = "bezier", points = { {0.34, 1.3}, {0.64, 1} } })
hl.curve("zx_fade",  { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.5, bezier = "zx_open", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "zx_close", style = "popin 80%" })
hl.animation({ leaf = "fadeIn",  enabled = true, speed = 3.5, bezier = "zx_fade" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 3, bezier = "zx_fade" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "zx_pace" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4.5, bezier = "zx_pace", style = "slidevert" })
hl.animation({ leaf = "layers", enabled = false })
