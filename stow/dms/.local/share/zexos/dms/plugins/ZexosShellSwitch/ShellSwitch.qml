// ZeXOS shell switcher: one bar button that opens `zshell menu`, the same
// menu as Mod+Shift+D. Noctalia has the same button on its bar.
// Plugin guide: https://danklinux.com/docs/dankmaterialshell/plugins
import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    pillClickAction: () => Quickshell.execDetached(["zshell", "menu"])

    horizontalBarPill: Component {
        DankIcon {
            name: "swap_horiz"
            size: root.iconSize
            color: Theme.widgetIconColor
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "swap_horiz"
            size: root.iconSize
            color: Theme.widgetIconColor
        }
    }
}
