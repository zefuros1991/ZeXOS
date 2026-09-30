-- How windows are placed and sized
--
-- Every workspace uses the "dwindle" layout: each new window takes half of
-- the window you are in, side by side on wide windows and one above the
-- other on tall ones. Think of folding a sheet of paper in half, then
-- folding one half again: nothing overlaps and nothing is off screen.
-- More: https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/

hl.config({
    general = {
        layout = "dwindle",

        -- Space between windows and at the screen edges, in pixels.
        gaps_in = 9,
        gaps_out = 9,

        -- Frame around every window. The colours are placeholders:
        -- noctalia.lua replaces them with colours from your wallpaper.
        border_size = 4,
        col = {
            active_border = "rgb(ffc87f)",
            inactive_border = "rgb(505050)",
        },
    },

    decoration = {
        -- Rounded corners.
        rounding = 14,
    },

    dwindle = {
        -- A split keeps its direction when windows around it change.
        -- Mod+J flips it between side by side and one above the other.
        preserve_split = true,
    },
})
