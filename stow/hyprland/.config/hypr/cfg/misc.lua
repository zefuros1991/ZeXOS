-- Small settings that don't fit anywhere else
--
-- Screenshots are saved to ~/Pictures/Screenshots by zexos-screenshot,
-- see the keys in keybinds.lua.

-- Settings passed to every app started from the desktop.
-- Qt apps (Dolphin, VLC...) take their look from qt6ct...
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- ...and are drawn 20% bigger.
hl.env("QT_SCALE_FACTOR", "1.2")

hl.config({
    misc = {
        -- The desktop shell draws the wallpaper, so Hyprland's own
        -- wallpaper and logo stay off.
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,

        -- Clicking a notification brings its window to the front.
        focus_on_activate = true,

        -- Screens off with Mod+Shift+P: any key or mouse move wakes them.
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },
})
