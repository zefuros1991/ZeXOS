-- Keyboard shortcuts
--
-- "SUPER" is the Mod key (the one with the Windows logo).
-- Each line reads: hl.bind("KEYS", what happens, { details }).
-- The description is the bind's name on the shortcut cheat sheet (Mod+F1),
-- and the "-- 1. Help" style lines are its headings. Keep every bind on
-- one line: the cheat sheets read this file line by line.
-- Shell actions go through `zshell`, so they work the same in Noctalia and
-- DankMaterialShell. `zshell --help` lists them.
-- All options: https://wiki.hypr.land/Configuring/Basics/Binds/

local exec = hl.dsp.exec_cmd

-- Screens off. Hyprland's docs ask to do this a moment after the key, not
-- straight from it. Any key or mouse move wakes the screens (misc.lua).
local function screens_off()
    hl.timer(function() hl.dispatch(hl.dsp.dpms({ action = "disable" })) end, { timeout = 500, type = "oneshot" })
end


-- 1. Help
hl.bind("SUPER + F1", exec("zshell cheatsheet"), { description = "Shortcut cheat sheet" })
hl.bind("SUPER + SHIFT + Escape", exec("zshell cheatsheet"), { description = "Shortcut cheat sheet" })

-- 2. Open apps
hl.bind("SUPER + space", exec("zshell launcher"), { description = "App launcher" })
hl.bind("SUPER + C", exec("kitty"), { description = "Terminal (kitty)" })
hl.bind("SUPER + B", exec("~/.local/bin/zexos-browser"), { description = "Web browser (your default)" })
hl.bind("SUPER + E", exec("dolphin"), { description = "Files (Dolphin)" })
hl.bind("SUPER + M", exec("~/.local/bin/zexos-app-store"), { description = "Install and update apps" })

-- 3. Wallpaper
hl.bind("SUPER + W", exec("pkill -x roller || PATH=$HOME/.local/share/roller/bin:$PATH roller"), { description = "Pick a wallpaper (roller)" })
hl.bind("SUPER + SHIFT + W", exec("pkill -x roller || PATH=$HOME/.local/share/roller/bin:$PATH roller --animated"), { description = "Pick an animated wallpaper" })
hl.bind("SUPER + CTRL + W", exec("zshell wallpaper-random"), { description = "Random wallpaper" })

-- 4. Session
hl.bind("SUPER + L", exec("zshell lock"), { description = "Lock the screen" })
hl.bind("SUPER + Escape", exec("zshell session"), { description = "Log out / restart / shut down" })
hl.bind("SUPER + SHIFT + D", exec("zshell menu"), { description = "Change desktop shell (Noctalia / DMS)" })
hl.bind("SUPER + SHIFT + P", screens_off, { description = "Screens off (press a key to wake them)" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exit(), { description = "Leave Hyprland and go back to the login screen" })
hl.bind("SUPER + SHIFT + R", exec("hyprctl reload"), { description = "Reload this configuration" })

-- 5. Laptop keys: sound, music, brightness
-- These work even on the lock screen (locked = true).
hl.bind("XF86AudioRaiseVolume", exec("zshell volume-up"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", exec("zshell volume-down"), { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute", exec("zshell volume-mute"), { locked = true, description = "Mute sound" })
hl.bind("XF86AudioMicMute", exec("zshell mic-mute"), { locked = true, description = "Mute microphone" })
hl.bind("XF86AudioPlay", exec("zshell media-toggle"), { locked = true, description = "Play / pause music" })
hl.bind("XF86AudioNext", exec("zshell media-next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPrev", exec("zshell media-prev"), { locked = true, description = "Previous track" })
hl.bind("XF86MonBrightnessUp", exec("zshell brightness-up"), { locked = true, repeating = true, description = "Screen brighter" })
hl.bind("XF86MonBrightnessDown", exec("zshell brightness-down"), { locked = true, repeating = true, description = "Screen dimmer" })

-- 6. Windows
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close the window" })
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }), { description = "Float the window / put it back" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Whole screen, bar stays visible" })
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Full screen, bar hidden" })
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"), { description = "Side by side / one above the other" })

-- 7. Move focus (arrows)
hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }), { description = "Focus the window to the left" })
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }), { description = "Focus the window to the right" })
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }), { description = "Focus the window above" })
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }), { description = "Focus the window below" })

-- 8. Move the window itself (add Ctrl)
-- Arrow keys or the vim keys H J K L both work.
hl.bind("SUPER + CTRL + left", hl.dsp.window.move({ direction = "left" }), { description = "Move the window left" })
hl.bind("SUPER + CTRL + H", hl.dsp.window.move({ direction = "left" }), { description = "Move the window left" })
hl.bind("SUPER + CTRL + right", hl.dsp.window.move({ direction = "right" }), { description = "Move the window right" })
hl.bind("SUPER + CTRL + L", hl.dsp.window.move({ direction = "right" }), { description = "Move the window right" })
hl.bind("SUPER + CTRL + up", hl.dsp.window.move({ direction = "up" }), { description = "Move the window up" })
hl.bind("SUPER + CTRL + K", hl.dsp.window.move({ direction = "up" }), { description = "Move the window up" })
hl.bind("SUPER + CTRL + down", hl.dsp.window.move({ direction = "down" }), { description = "Move the window down" })
hl.bind("SUPER + CTRL + J", hl.dsp.window.move({ direction = "down" }), { description = "Move the window down" })

-- 9. Sizes
-- Each press moves the line between two windows by 100 pixels: one
-- window grows, its neighbour shrinks. (On the right-hand window,
-- Mod+Equal therefore makes it smaller: the line moves right.)
hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true, description = "Move the split left" })
hl.bind("SUPER + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true, description = "Move the split right" })
hl.bind("SUPER + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true, description = "Move the split up" })
hl.bind("SUPER + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true, description = "Move the split down" })

-- 10. Several screens (add Shift)
-- ...and Shift+Ctrl carries the window with you.
hl.bind("SUPER + SHIFT + left", hl.dsp.focus({ monitor = "left" }), { description = "Focus the screen left" })
hl.bind("SUPER + SHIFT + right", hl.dsp.focus({ monitor = "right" }), { description = "Focus the screen right" })
hl.bind("SUPER + SHIFT + up", hl.dsp.focus({ monitor = "up" }), { description = "Focus the screen above" })
hl.bind("SUPER + SHIFT + down", hl.dsp.focus({ monitor = "down" }), { description = "Focus the screen below" })
hl.bind("SUPER + SHIFT + CTRL + left", hl.dsp.window.move({ monitor = "left" }), { description = "Move the window to the screen left" })
hl.bind("SUPER + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "right" }), { description = "Move the window to the screen right" })
hl.bind("SUPER + SHIFT + CTRL + up", hl.dsp.window.move({ monitor = "up" }), { description = "Move the window to the screen above" })
hl.bind("SUPER + SHIFT + CTRL + down", hl.dsp.window.move({ monitor = "down" }), { description = "Move the window to the screen below" })

-- 11. Workspaces
-- Mod+number goes to that workspace; Mod+Ctrl+number takes the window along.
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }), { description = "Workspace 1" })
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = 2 }), { description = "Workspace 2" })
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = 3 }), { description = "Workspace 3" })
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = 4 }), { description = "Workspace 4" })
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = 5 }), { description = "Workspace 5" })
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = 6 }), { description = "Workspace 6" })
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = 7 }), { description = "Workspace 7" })
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = 8 }), { description = "Workspace 8" })
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = 9 }), { description = "Workspace 9" })
hl.bind("SUPER + CTRL + 1", hl.dsp.window.move({ workspace = 1 }), { description = "Move the window to workspace 1" })
hl.bind("SUPER + CTRL + 2", hl.dsp.window.move({ workspace = 2 }), { description = "Move the window to workspace 2" })
hl.bind("SUPER + CTRL + 3", hl.dsp.window.move({ workspace = 3 }), { description = "Move the window to workspace 3" })
hl.bind("SUPER + CTRL + 4", hl.dsp.window.move({ workspace = 4 }), { description = "Move the window to workspace 4" })
hl.bind("SUPER + CTRL + 5", hl.dsp.window.move({ workspace = 5 }), { description = "Move the window to workspace 5" })
hl.bind("SUPER + CTRL + 6", hl.dsp.window.move({ workspace = 6 }), { description = "Move the window to workspace 6" })
hl.bind("SUPER + CTRL + 7", hl.dsp.window.move({ workspace = 7 }), { description = "Move the window to workspace 7" })
hl.bind("SUPER + CTRL + 8", hl.dsp.window.move({ workspace = 8 }), { description = "Move the window to workspace 8" })
hl.bind("SUPER + CTRL + 9", hl.dsp.window.move({ workspace = 9 }), { description = "Move the window to workspace 9" })
hl.bind("SUPER + Tab", hl.dsp.focus({ workspace = "previous" }), { description = "Back to the last workspace" })

-- 12. Screenshots
-- Saved to ~/Pictures/Screenshots and copied to the clipboard.
hl.bind("SUPER + SHIFT + S", exec("zexos-screenshot area"), { description = "Screenshot of an area (drag to pick it)" })
hl.bind("CTRL + SHIFT + S", exec("zexos-screenshot screen"), { description = "Screenshot of the whole screen" })
hl.bind("ALT + SHIFT + 3", exec("zexos-screenshot window"), { description = "Screenshot of the focused window" })

-- 13. Mouse
-- Hold Mod and drag with the left button to move a window, with the right
-- button to resize it.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move the window (drag)" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize the window (drag)" })
-- Hold Mod and scroll: up/down changes workspace, sideways moves between
-- windows. Add Ctrl to take the window along.
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "m-1" }), { description = "Previous workspace" })
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "m+1" }), { description = "Next workspace" })
hl.bind("SUPER + mouse_left", hl.dsp.focus({ direction = "left" }), { description = "Focus the window to the left" })
hl.bind("SUPER + mouse_right", hl.dsp.focus({ direction = "right" }), { description = "Focus the window to the right" })
hl.bind("SUPER + CTRL + mouse_up", hl.dsp.window.move({ workspace = "r-1" }), { description = "Move the window to the previous workspace" })
hl.bind("SUPER + CTRL + mouse_down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Move the window to the next workspace" })
hl.bind("SUPER + CTRL + mouse_left", hl.dsp.window.move({ direction = "left" }), { description = "Move the window left" })
hl.bind("SUPER + CTRL + mouse_right", hl.dsp.window.move({ direction = "right" }), { description = "Move the window right" })
