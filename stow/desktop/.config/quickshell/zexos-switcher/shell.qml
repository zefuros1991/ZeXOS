// The shell switcher (Mod+Shift+D), started by `zshell menu`.
// It has no search box on purpose: a stray key press can't hide the choices.
// Keys: Up/Down (or Tab, j/k) to move, Enter/Space to pick, 1/2 to pick
// straight away, Esc or a click outside to close.
//
// zshell passes everything in through environment variables:
//   ZX_ITEMS   JSON list of {id, name, icon, current}
//   ZX_BG, ZX_TEXT, ZX_ACCENT, ZX_SELECTION, ZX_BORDER
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
            // 1.4x the old fuzzel menu, and the two choices fill all of it.
            width: 560
            height: column.implicitHeight + 2 * 22
            anchors.centerIn: parent
            radius: 32
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
                anchors { fill: parent; margins: 22 }
                spacing: 12

                Repeater {
                    model: root.items

                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.selected

                        Layout.fillWidth: true
                        implicitHeight: 118
                        radius: 20
                        color: active ? root.colour("ZX_SELECTION", "#80ac67e4") : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = row.index
                            onClicked: root.pick(row.index)
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 26; rightMargin: 26 }
                            spacing: 24

                            Image {
                                Layout.preferredWidth: 86
                                Layout.preferredHeight: 86
                                source: Quickshell.iconPath(row.modelData.icon, true)
                                sourceSize: Qt.size(172, 172)
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
                                    font.pixelSize: 34
                                    font.letterSpacing: 0.4
                                    color: root.colour("ZX_TEXT", "#fff2f2f3")
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: row.modelData.current
                                    text: "IN USE"
                                    font.family: "Nunito"
                                    font.weight: Font.Bold
                                    font.pixelSize: 15
                                    font.letterSpacing: 2.5
                                    color: root.colour("ZX_ACCENT", "#ffd65cd1")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
