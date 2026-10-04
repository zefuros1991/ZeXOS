-- Keyboard, touchpad and mouse
-- All options: https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
    input = {
        -- Keyboard layout. Example for English + Greek, switched with Alt+Shift:
        --   kb_layout = "us,gr",
        --   kb_options = "grp:alt_shift_toggle",
        kb_layout = "us",

        -- Number pad works right after login.
        numlock_by_default = true,

        -- Moving the pointer over a window gives it focus, no click needed.
        follow_mouse = 1,

        -- Touchpad: a light tap counts as a click, and content follows your
        -- fingers, like a phone.
        touchpad = {
            tap_to_click = true,
            natural_scroll = true,
        },
    },

    -- The pointer stays where it is when you focus a window with the
    -- keyboard. Set to false to make it jump to the window instead.
    cursor = {
        no_warps = true,
    },
})

-- Three fingers up or down on the touchpad changes workspace, like niri.
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
