"""The 12 basic keys on the Keys page (REQ-8), in this order.

Each "Try it" runs the same command the key is bound to (see
stow/niri/.config/niri/cfg/keybinds.kdl, stow/mango/.config/mango/cfg/keybinds.conf,
stow/hyprland/.config/hypr/cfg/keybinds.lua and overview.lua). If a key bind
changes there, change it here too.
"""

ROLLER = "pkill -x roller || PATH=$HOME/.local/share/roller/bin:$PATH roller"

# caps, label, note, command (str, or {compositor: str}), needs
KEYS = [
    (["Mod", "Space"], "App launcher", None, "zshell launcher", None),
    (["Mod", "C"], "Terminal", None, "kitty", None),
    (["Mod", "B"], "Web browser", None, "$HOME/.local/bin/zexos-browser", None),
    (["Mod", "E"], "Files", None, "dolphin", None),
    (["Mod", "M"], "Get apps", None, "$HOME/.local/bin/zexos-app-store", None),
    (["Mod", "W"], "Pick a wallpaper", None, ROLLER, None),
    (["Mod", "O"], "Overview of all workspaces", None,
     {"niri": "niri msg action toggle-overview", "mango": "mango-overview toggle", "hyprland": "mango-overview toggle"}, None),
    (["Mod", "Shift", "D"], "Change desktop shell",
     "Restarts the bar in the other look; your windows stay open.", "zshell menu", "two-shells"),
    (["Mod", "L"], "Lock the screen", "Locks your screen; type your password to come back.", "zshell lock", None),
    (["Mod", "Esc"], "Power menu", "Opens log out, restart and shut down.", "zshell session", None),
    (["Mod", "Q"], "Close a window", "No Try it here: it would close this welcome window.", None, None),
    (["Mod", "F1"], "All keys", None, "zshell cheatsheet", None),
]

NOT_INSTALLED = "Not installed on this computer."


def command(cmd, compositor):
    if isinstance(cmd, dict):
        return cmd.get(compositor) or cmd.get("niri")
    return cmd
