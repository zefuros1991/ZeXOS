-- Written by DankMaterialShell from ZeXOS's template. Don't edit this file: it is
-- rewritten every time the wallpaper changes.
-- The focused window gets a gradient in the wallpaper colours, the others
-- a faint line. shell-colors.lua loads this after dms/colors.lua, so it wins.
hl.config({
    general = {
        col = {
            active_border = {
                colors = { "rgb({{colors.primary.default.hex_stripped}})", "rgb({{colors.tertiary.default.hex_stripped}})" },
                angle = 135,
            },
            inactive_border = "rgb({{colors.outline_variant.default.hex_stripped}})",
        },
    },
})
