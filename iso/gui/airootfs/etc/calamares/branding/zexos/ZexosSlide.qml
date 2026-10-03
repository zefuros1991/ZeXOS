/* One slideshow page: a ZeXOS wallpaper with a title and a line of text. */
import QtQuick
import calamares.slideshow 1.0

Slide {
    id: slide
    property string backdrop
    property string title
    property string body
    anchors.fill: parent

    Image {
        anchors.fill: parent
        source: slide.backdrop
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.35; color: "#000f0f14" }
            GradientStop { position: 1.0;  color: "#e60f0f14" }
        }
    }
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 40
        spacing: 10
        Text {
            text: slide.title
            color: "#ffffff"
            font.pixelSize: 30
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            text: slide.body
            color: "#c8c8d8"
            font.pixelSize: 16
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
    }
}
