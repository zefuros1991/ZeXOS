-- Looks and per-app tweaks
--
-- A window rule changes app windows: "match" says which app (a pattern
-- matched against the app's id, called "class" here), the rest says what
-- changes. When two rules set the same thing, the later one wins.
-- More: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

hl.config({
    decoration = {
        -- Windows you're not using fade slightly, so the active one stands out.
        active_opacity = 1.0,
        inactive_opacity = 0.86,

        -- No shadows (the same as niri here). Set to true to try them.
        shadow = { enabled = false },

        -- Frosted-glass blur behind see-through windows. The rule below
        -- keeps it for kitty, VLC and Dolphin only.
        blur = { enabled = true },
    },
})

-- ── Apps ────────────────────────────────────────────────

-- Blur off for every app except kitty, VLC and Dolphin. ("negative:"
-- means "every app that does NOT match".)
hl.window_rule({ name = "zexos-no-blur", match = { class = [[negative:^(kitty|vlc|org\.kde\.dolphin)$]] }, no_blur = true })

-- Noctalia's settings window floats above the others.
hl.window_rule({ name = "zexos-noctalia-settings", match = { class = [[^dev\.noctalia\.Noctalia$]] }, float = true })

-- The desktop shell's own pieces (bar, panels, pop-ups) get no blur or
-- shadow: layers have none unless a rule turns them on, so there is
-- nothing to do here. Their animation is off in animation.lua.
