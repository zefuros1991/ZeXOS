-- The overview (mango-overview): every workspace as a card, stacked top to
-- bottom, with live window previews, like niri's.
-- Open it with Mod+O, or four fingers up on the touchpad.
-- Inside: arrows / WASD / HJKL to move, Enter or a click to go there,
-- middle-click closes a window, Esc goes back.

local exec = hl.dsp.exec_cmd
hl.bind("SUPER + O", exec("mango-overview toggle"), { description = "Overview of all workspaces" })

-- While the overview is open, Hyprland's own keys are off (the overview
-- turns on this submap), so the keys reach the overview. It also blocks
-- Hyprland's shortcuts and touchpad gestures while it has the keyboard, so
-- a three-finger swipe moves the overview and not the desktop behind it.
-- Only these get through (dont_inhibit / disable_inhibit):
hl.define_submap("overview", function()
    hl.bind("SUPER + O", exec("mango-overview toggle"), { dont_inhibit = true })
    -- Way out if the overview ever stops answering.
    hl.bind("SUPER + Escape", exec("mango-overview close; hyprctl dispatch 'hl.dsp.submap(\"reset\")'"), { dont_inhibit = true })
    -- Screenshots (the same keys as in keybinds.lua).
    hl.bind("SUPER + SHIFT + S", exec("zexos-screenshot area"), { dont_inhibit = true })
    hl.bind("CTRL + SHIFT + S", exec("zexos-screenshot screen"), { dont_inhibit = true })
    hl.bind("ALT + SHIFT + 3", exec("zexos-screenshot window"), { dont_inhibit = true })
end)

-- Touchpad: four fingers up opens it, four fingers down closes it.
-- Inside it, three fingers up or down drag the workspaces (the overview
-- reads the swipe itself).
hl.gesture({ fingers = 4, direction = "up", action = function() hl.exec_cmd("mango-overview open") end, disable_inhibit = true })
hl.gesture({ fingers = 4, direction = "down", action = function() hl.exec_cmd("mango-overview close") end, disable_inhibit = true })

-- No open/close animation for the overview's layers: it animates itself.
hl.layer_rule({ name = "zexos-overview", match = { namespace = "^mango-overview" }, no_anim = true })
