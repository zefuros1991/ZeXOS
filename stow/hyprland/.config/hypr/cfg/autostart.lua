-- Things that start when you log in

hl.on("hyprland.start", function()
    -- The desktop shell: top bar, launcher, notifications, lock screen.
    -- zshell starts the one you picked (Noctalia or DankMaterialShell);
    -- press Mod+Shift+D to change it.
    -- The overview (cfg/overview.lua). Started before the shell, so the
    -- shell's menus open on top of it.
    hl.exec_cmd("mango-overview")

    hl.exec_cmd("zshell start")

    -- The small window that asks for your password when an app needs admin rights.
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
end)
