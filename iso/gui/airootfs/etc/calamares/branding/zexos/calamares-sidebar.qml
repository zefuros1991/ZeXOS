/* ZeXOS sidebar: logo on top, then the steps, the current one highlighted. */
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: sideBar
    color: Branding.styleString(Branding.SidebarBackground)
    width: 210
    height: parent.height

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            Layout.bottomMargin: 18
            source: "file:/" + Branding.imagePath(Branding.ProductLogo)
            sourceSize.width: 72
            sourceSize.height: 72
        }

        Repeater {
            model: ViewManager
            Rectangle {
                readonly property bool current: index == ViewManager.currentStepIndex
                readonly property bool done: index < ViewManager.currentStepIndex
                Layout.fillWidth: true
                height: 36
                radius: 8
                color: current ? Branding.styleString(Branding.SidebarBackgroundCurrent) : "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    spacing: 10
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: current ? "#ffffff" : (done ? "#3DDC97" : "#3a3a4c")
                    }
                    Text {
                        text: display
                        color: current ? Branding.styleString(Branding.SidebarTextCurrent)
                                       : (done ? "#e6e6ef" : Branding.styleString(Branding.SidebarText))
                        font.pixelSize: 14
                        font.weight: current ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Branding.versionedName()
            color: "#5a5a6e"
            font.pixelSize: 11
        }
    }
}
