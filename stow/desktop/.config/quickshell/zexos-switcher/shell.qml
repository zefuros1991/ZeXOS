// The shell switcher (Mod+Shift+D), started by `zshell menu`.
// It has no search box on purpose: a stray key press can't hide the choices.
// Keys: Up/Down (or Tab, j/k) to move, Enter/Space to pick, 1/2 to pick
// straight away, Esc or a click outside to close.
//
// zshell passes everything in through environment variables:
//   ZX_ITEMS   JSON list of {id, name, icon, current}
//   ZX_BG, ZX_BORDER (also used as the theme colour for the names)
//              colours as #AARRGGBB, from the shell's fuzzel colours
// Quickshell docs: https://quickshell.org/docs/types/Quickshell.Wayland/WlrLayershell/

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property var items: JSON.parse(Quickshell.env("ZX_ITEMS") || "[]")
    function colour(name, fallback) { return Quickshell.env(name) || fallback }

    // The shell names take the theme's main colour. The selected row is a
    // light tint of it with an outline, so the names stay readable on it.
    readonly property color themeColour: colour("ZX_BORDER", "#ffac67e4")
    readonly property color selectionTint: Qt.rgba(themeColour.r, themeColour.g, themeColour.b, 0.22)

    // Start on the first shell that is not in use, so Enter switches.
    property int selected: Math.max(0, items.findIndex(i => !i.current))

    function pick(index) {
        const item = items[index]
        if (item && !item.current)
            Quickshell.execDetached(["zshell", "switch", item.id])
        Qt.quit()
    }

    PanelWindow {
        // A see-through window over the whole screen: clicks outside the
        // card close the menu, and the keyboard is ours while it is open.
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "zexos-switcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        Rectangle {
            id: card
            // About 1.2x the old fuzzel menu, and the two choices fill all of it.
            width: 476
            height: column.implicitHeight + 2 * 19
            anchors.centerIn: parent
            radius: 27
            color: root.colour("ZX_BG", "#cc200f2f")
            border.width: 2
            border.color: root.colour("ZX_BORDER", "#ffac67e4")

            focus: true
            Keys.onPressed: event => {
                const n = root.items.length
                switch (event.key) {
                case Qt.Key_Escape:
                    Qt.quit(); break
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                    root.pick(root.selected); break
                case Qt.Key_Up: case Qt.Key_Left: case Qt.Key_K: case Qt.Key_Backtab:
                    root.selected = (root.selected - 1 + n) % n; break
                case Qt.Key_Down: case Qt.Key_Right: case Qt.Key_J: case Qt.Key_Tab:
                    root.selected = (root.selected + 1) % n; break
                default:
                    const digit = event.key - Qt.Key_1
                    if (digit >= 0 && digit < n) root.pick(digit)
                }
                event.accepted = true   // every other key does nothing
            }

            // Swallow clicks on the card itself, so only outside clicks close.
            MouseArea { anchors.fill: parent }

            // Pop in softly.
            opacity: 0
            scale: 0.96
            Component.onCompleted: { opacity = 1; scale = 1 }
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: column
                anchors { fill: parent; margins: 19 }
                spacing: 10

                Repeater {
                    model: root.items

                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.selected

                        Layout.fillWidth: true
                        implicitHeight: 100
                        radius: 17
                        color: active ? root.selectionTint : "transparent"
                        border.width: active ? 2 : 0
                        border.color: root.themeColour
                        Behavior on color { ColorAnimation { duration: 120 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = row.index
                            onClicked: root.pick(row.index)
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
                            spacing: 20

                            Image {
                                Layout.preferredWidth: 73
                                Layout.preferredHeight: 73
                                source: Quickshell.iconPath(row.modelData.icon, true)
                                sourceSize: Qt.size(146, 146)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    font.family: "Nunito"
                                    font.weight: Font.ExtraBold
                                    font.pixelSize: 29
                                    font.letterSpacing: 0.4
                                    color: root.themeColour
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: row.modelData.current
                                    text: "IN USE"
                                    font.family: "Nunito"
                                    font.weight: Font.Bold
                                    font.pixelSize: 13
                                    font.letterSpacing: 2.2
                                    color: "#d6a85c"   // always this orange, whatever the theme
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
