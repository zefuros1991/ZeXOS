// The shell-switch curtain, started by `zshell switch` before it swaps shells.
//
// Two layers per screen:
//   - a copy of your wallpaper at the very back (the background layer). The
//     wallpaper belongs to the shell, so while one shell has quit and the
//     other is still starting, the compositor would show its bare grey
//     background. This copy fills that gap, so there is no grey.
//   - the curtain on top (the overlay layer), in the style you picked with
//     `zexos-motion set switch ...`. It hides the old shell going and the new
//     one arriving, then `zshell` lifts it with:
//       qs ipc -c zexos-curtain call curtain lift
//
// If nobody lifts it, it lifts itself after 8 seconds. It quits a moment
// after lifting, once the new shell has drawn its own wallpaper.
//
// Inputs (environment variables):
//   ZX_STYLE   wipe | dip | logo | none
//   ZX_WALL    the wallpaper picture (empty = plain background colour)
//   ZX_BG, ZX_ACCENT   colours as #AARRGGBB
//   ZX_ICON, ZX_NAME   the new shell's logo icon name and display name
// Quickshell docs: https://quickshell.org/docs/types/Quickshell.Wayland/WlrLayershell/

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string style: Quickshell.env("ZX_STYLE") || "wipe"
    readonly property string wall: Quickshell.env("ZX_WALL") || ""
    readonly property color bg: Quickshell.env("ZX_BG") || "#ff101512"
    readonly property color accent: Quickshell.env("ZX_ACCENT") || "#ff7ee0a0"
    readonly property string icon: Quickshell.env("ZX_ICON") || ""
    readonly property string name: Quickshell.env("ZX_NAME") || ""

    // 0 = hidden, 1 = covering, 2 = leaving
    property int phase: 0

    function lift() { if (phase === 1) phase = 2 }

    IpcHandler {
        target: "curtain"
        function lift(): void { root.lift() }
    }

    Timer { interval: 8000; running: true; onTriggered: root.lift() }
    // The curtain is gone after ~0.6 s; the wallpaper copy stays a little
    // longer, until the new shell's own wallpaper is surely on screen.
    Timer { id: quitLater; interval: 2500; onTriggered: Qt.quit() }
    onPhaseChanged: if (phase === 2) quitLater.start()
    Component.onCompleted: phase = 1

    // The wallpaper copy.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "zexos-curtain-wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: root.bg

            Image {
                anchors.fill: parent
                source: root.wall ? "file://" + root.wall : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
            }
        }
    }

    // The curtain.
    Variants {
        model: root.style === "none" ? [] : Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zexos-curtain"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            // dip: the whole screen fades to the background colour and back.
            Rectangle {
                visible: root.style === "dip"
                anchors.fill: parent
                color: root.bg
                opacity: root.phase === 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.phase === 2 ? 450 : 220; easing.type: Easing.InOutCubic } }
            }

            // logo: like dip, plus the new shell's logo and name growing in.
            Item {
                visible: root.style === "logo"
                anchors.fill: parent
                opacity: root.phase === 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.phase === 2 ? 450 : 250; easing.type: Easing.InOutCubic } }
                Rectangle { anchors.fill: parent; color: root.bg }
                Column {
                    anchors.centerIn: parent
                    spacing: 18
                    scale: root.phase === 1 ? 1 : 0.85
                    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
                        sourceSize: Qt.size(112, 112)
                        width: 112; height: 112
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.name
                        color: root.accent
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                    }
                }
            }

            // wipe: a sheet sweeps up from the bottom, then keeps going off
            // the top to uncover the new shell. A thin accent line leads it.
            Item {
                visible: root.style === "wipe"
                anchors.fill: parent
                clip: true
                Rectangle {
                    width: parent.width
                    height: parent.height
                    color: root.bg
                    y: root.phase === 0 ? parent.height : root.phase === 1 ? 0 : -parent.height
                    Behavior on y { NumberAnimation { duration: root.phase === 2 ? 550 : 380; easing.type: Easing.InOutCubic } }
                    Rectangle {
                        width: parent.width; height: 6
                        color: root.accent
                        anchors.top: root.phase === 2 ? undefined : parent.top
                        anchors.bottom: root.phase === 2 ? parent.bottom : undefined
                    }
                }
            }
        }
    }
}
