/* Multi-select picker with an animated preview, used by the compositor and
 * shell pages. Ticked options go to config.packageChoice, space separated
 * ("niri mango"); the install step reads them from there. At least one
 * option always stays ticked. */
import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: picker
    property string heading
    property string subheading
    property string footnote
    property var options: []      // [{ id, name, tag, text }]
    property var picked: config.packageChoice.split(" ").filter(function (s) { return s.length > 0 })
    property string shown: options.length ? options[0].id : ""
    property bool warnLast: false

    // The clip must start from the beginning every time this page is
    // entered, from either direction. Calamares shows the page and draws it
    // straight away, before telling us, so rewinding on arrival flashes
    // whatever frame was showing. Instead the clip is parked at its first
    // frame (paused) as soon as the page is left, and only started again
    // on arrival: the first thing drawn is then always frame 0.
    // (packagechooserq does not pass onLeave on, so leaving is spotted
    // through ViewManager: a step change that was not our own arrival.)
    property bool running: false
    property bool arriving: false
    function onActivate() {
        arriving = true
        running = true
    }
    Connections {
        target: ViewManager
        function onCurrentStepChanged() {
            if (picker.arriving) { picker.arriving = false; return }
            picker.running = false
            preview.currentFrame = 0
        }
    }

    color: "#0f0f14"

    function isPicked(id) { return picked.indexOf(id) >= 0 }
    function toggle(id) {
        var p = picked.slice()
        var i = p.indexOf(id)
        if (i >= 0) {
            if (p.length === 1) { warnLast = true; return }
            p.splice(i, 1)
        } else {
            p.push(id)
        }
        warnLast = false
        // Keep the order the options are listed in.
        p = options.map(function (o) { return o.id }).filter(function (x) { return p.indexOf(x) >= 0 })
        picked = p
        config.packageChoice = p.join(" ")
    }
    function optionFor(id) {
        for (var i = 0; i < options.length; i++) if (options[i].id === id) return options[i]
        return { name: "", tag: "", text: "" }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 28

        ColumnLayout {
            Layout.preferredWidth: 360
            Layout.maximumWidth: 400
            Layout.fillHeight: true
            spacing: 12

            Text {
                text: picker.heading
                color: "#ffffff"
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: picker.subheading
                color: "#9a9ab0"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.bottomMargin: 8
            }

            Repeater {
                model: picker.options
                Rectangle {
                    readonly property bool on: picker.isPicked(modelData.id)
                    readonly property bool focused: picker.shown === modelData.id
                    Layout.fillWidth: true
                    implicitHeight: card.implicitHeight + 28
                    radius: 12
                    color: mouse.containsMouse ? "#20202c" : "#1a1a24"
                    border.width: 2
                    border.color: on ? "#7C5CFF" : (focused ? "#3a3a4c" : "#22222e")
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: card
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 14
                        spacing: 14

                        Rectangle {   // the tick box
                            width: 22; height: 22; radius: 6
                            Layout.alignment: Qt.AlignTop
                            color: on ? "#7C5CFF" : "transparent"
                            border.width: 2
                            border.color: on ? "#7C5CFF" : "#5a5a6e"
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                visible: on
                                color: "#ffffff"
                                font.pixelSize: 15
                                font.bold: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData.name
                                    color: "#e6e6ef"
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: modelData.tag
                                    color: "#a78bfa"
                                    font.pixelSize: 12
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.text
                                color: "#9a9ab0"
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: picker.shown = modelData.id
                        onClicked: { picker.shown = modelData.id; picker.toggle(modelData.id) }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: picker.warnLast ? "Keep at least one ticked." : picker.footnote
                color: picker.warnLast ? "#f5a97f" : "#6a6a80"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
            Item { Layout.fillHeight: true }
        }

        Item {   // the preview of whatever is hovered or last clicked
            id: previewArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            // The box takes the clip's own shape and is as big as fits, so
            // there are no empty bands around the clip at any window size.
            // Kept from the last loaded clip, so a rewind or a clip switch
            // can never make the box jump to a different size for a frame.
            property real ratio: 16 / 9
            readonly property real pad: 8
            readonly property real boxWidth: Math.min(width,
                (height - caption.height - previewColumn.spacing - 2 * pad) * ratio + 2 * pad)

            Column {
                id: previewColumn
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    width: previewArea.boxWidth
                    height: (width - 2 * previewArea.pad) / previewArea.ratio + 2 * previewArea.pad
                    radius: 14
                    color: "#14141c"
                    border.width: 1
                    border.color: "#22222e"
                    clip: true

                    AnimatedImage {
                        id: preview
                        anchors.fill: parent
                        anchors.margins: previewArea.pad
                        source: picker.shown ? "previews/" + picker.shown + ".webp" : ""
                        fillMode: Image.PreserveAspectFit
                        playing: picker.running
                        speed: 1   // clips are recorded at real speed
                        cache: false
                        onStatusChanged: if (status === Image.Ready && implicitHeight > 0)
                            previewArea.ratio = implicitWidth / implicitHeight
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
                Text {
                    id: caption
                    width: previewArea.boxWidth
                    horizontalAlignment: Text.AlignHCenter
                    text: picker.optionFor(picker.shown).name + "  ·  " + picker.optionFor(picker.shown).tag
                    color: "#9a9ab0"
                    font.pixelSize: 13
                }
            }
        }
    }
}
