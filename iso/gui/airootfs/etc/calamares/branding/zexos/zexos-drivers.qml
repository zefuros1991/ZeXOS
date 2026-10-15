/* Drivers page (packagechooserq@drivers): shows what zexos-drivers found on
 * this computer and the driver it picked for each chip, with the other
 * driver that can work where there is one. zexos-gui-installer saves the
 * scan to /tmp/zexos-drivers-plan.json before Calamares starts.
 *  - config.packageChoice gets the readable lines ("NVIDIA GeForce RTX 4070 →
 *    newest NVIDIA driver"), which the summary page shows.
 *  - Global "zexosDrivers" gets the chosen driver sets; zexos-desktop.conf
 *    hands them to zexos-calamares-finish, which writes
 *    /tmp/zexos-drivers-choice for zexos-install-into. */
import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: page
    width: parent.width
    height: parent.height
    color: "#0f0f14"

    property var plan: ({ chips: [], sets: [], alternatives: {}, descs: {}, notes: [] })
    property var picks: ({})          // chip slot -> chosen set
    property bool loaded: false

    function desc(s) { return (plan.descs && plan.descs[s]) ? plan.descs[s] : s }

    function load() {
        var x = new XMLHttpRequest()
        x.open("GET", "file:///tmp/zexos-drivers-plan.json", false)
        try { x.send() } catch (e) { }
        try { plan = JSON.parse(x.responseText) } catch (e) { plan = { chips: [], sets: [], alternatives: {}, descs: {}, notes: [] } }
        var p = {}
        for (var i = 0; i < plan.chips.length; i++) p[plan.chips[i].slot] = plan.chips[i].set
        picks = p
        loaded = true
        save()
    }

    // Sets that belong to no single chip (laptop battery saving, Intel power saving).
    function extraSets() {
        var chipSets = plan.chips.map(function (c) { return c.set })
        return plan.sets.filter(function (s) { return chipSets.indexOf(s) < 0 })
    }

    function chosenSets() {
        var out = []
        for (var i = 0; i < plan.chips.length; i++) {
            var s = picks[plan.chips[i].slot]
            if (s && out.indexOf(s) < 0) out.push(s)
        }
        var nvidiaDriver = out.indexOf("nvidia-newest") >= 0 || out.indexOf("nvidia-legacy") >= 0
        extraSets().forEach(function (s) {
            // The laptop extras only make sense with an NVIDIA driver.
            if (s === "hybrid" && !nvidiaDriver) return
            if (out.indexOf(s) < 0) out.push(s)
        })
        return out
    }

    function save() {
        var lines = plan.chips.map(function (c) { return c.name + " → " + desc(picks[c.slot]) })
        extraSets().forEach(function (s) {
            if (chosenSets().indexOf(s) >= 0) lines.push("Also: " + desc(s))
        })
        config.packageChoice = lines.length ? lines.join("; ") : "No extra drivers needed"
        // The install step gets the chosen sets through Calamares' shared
        // storage, like the compositor and shell picks.
        Global.insert("zexosDrivers", chosenSets().join(","))
    }

    function choose(slot, s) {
        var p = Object.assign({}, picks)
        p[slot] = s
        picks = p
        save()
    }

    Component.onCompleted: load()
    function onActivate() { if (!loaded) load() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 12

        Text {
            text: "Drivers"
            color: "#ffffff"
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "ZeXOS looked at this computer's graphics, Wi-Fi and network chips and picked a driver for each. Where another driver can work, you can choose it."
            color: "#9a9ab0"
            font.pixelSize: 14
        }

        Repeater {
            model: page.plan.chips
            delegate: Rectangle {
                id: card
                required property var modelData
                property string slot: modelData.slot
                property var alts: [modelData.set].concat(page.plan.alternatives[modelData.set] || [])
                Layout.fillWidth: true
                Layout.preferredHeight: col.implicitHeight + 28
                radius: 12
                color: "#1a1a24"
                border.width: 2
                border.color: "#22222e"

                ColumnLayout {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 16
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.name + "  →  " + page.desc(page.picks[modelData.slot])
                        color: "#e6e6ef"
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: alts.length > 1
                        Repeater {
                            model: alts
                            delegate: Rectangle {
                                required property var modelData
                                property bool on: page.picks[card.slot] === modelData
                                width: label.implicitWidth + 28
                                height: 32
                                radius: 8
                                color: on ? "#7C5CFF" : (ma.containsMouse ? "#20202c" : "transparent")
                                border.width: 2
                                border.color: on ? "#7C5CFF" : "#3a3a4c"
                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: page.desc(modelData)
                                    color: "#ffffff"
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.choose(card.slot, modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: page.loaded && page.plan.chips.length === 0
            text: "No extra drivers are needed on this computer."
            color: "#e6e6ef"
            font.pixelSize: 15
        }
        Repeater {
            // Follows the picks: the laptop extras go away with the open-source driver.
            model: { page.picks; return page.extraSets().filter(function (s) { return page.chosenSets().indexOf(s) >= 0 }) }
            delegate: Text {
                required property var modelData
                text: "Also: " + page.desc(modelData)
                color: "#a78bfa"
                font.pixelSize: 13
            }
        }
        Repeater {
            model: page.plan.notes
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: modelData
                color: "#f5a97f"
                font.pixelSize: 12
            }
        }
        Item { Layout.fillHeight: true }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Drivers can be changed later in ZeXOS - Welcome → Drivers, or with the zexos-drivers command."
            color: "#6a6a80"
            font.pixelSize: 12
        }
    }
}
