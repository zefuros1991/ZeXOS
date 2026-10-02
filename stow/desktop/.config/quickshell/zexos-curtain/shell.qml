// The shell-switch curtain, started by `zshell switch` before it swaps shells.
//
// What you see (style "logo", the default):
//   1. the screen fades (0.7 s) to a dark shade of the main colour of the old
//      shell's wallpaper, with the new shell's logo large in the middle;
//   2. while the shells swap behind it, that colour slowly turns (2.2 s) into
//      a dark shade of the new shell's wallpaper colour;
//   3. once the new shell is up, everything fades out (0.8 s) to it.
// Style "dip" is the same without the logo. Style "none" shows no curtain.
//
// `zshell` asks `qs ipc -c zexos-curtain call curtain state` until it says
// "covered" before it stops the old shell, and calls `... curtain lift` once
// the new one is up. If nobody lifts it, it lifts itself after 10 seconds.
//
// Under the curtain, a copy of the new wallpaper sits at the very back (the
// background layer), so if the new shell is slow to draw its own wallpaper
// the fade-out still lands on it and not on the compositor's bare grey. It
// fades away a moment later.
//
// Inputs (environment variables):
//   ZX_STYLE      logo | dip | none
//   ZX_OLD_WALL   the old shell's wallpaper picture (for the start colour)
//   ZX_WALL       the new shell's wallpaper picture (for the end colour)
//   ZX_BG         #AARRGGBB, used when a wallpaper can't be read
//   ZX_ICON       the new shell's logo icon name
// Quickshell docs: https://quickshell.org/docs/types/Quickshell.Wayland/WlrLayershell/
// Qt Canvas docs: https://doc.qt.io/qt-6/qml-qtquick-canvas.html

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string style: Quickshell.env("ZX_STYLE") || "logo"
    readonly property string oldWall: Quickshell.env("ZX_OLD_WALL") || ""
    readonly property string newWall: Quickshell.env("ZX_WALL") || ""
    readonly property color fallback: Quickshell.env("ZX_BG") || "#ff101512"
    readonly property string icon: Quickshell.env("ZX_ICON") || ""

    // How long each part takes (ms).
    readonly property int fadeIn: 700
    readonly property int shift: 2200
    readonly property int fadeOut: 800

    // The two dark shades. Filled in by the colour pickers below.
    property color fromColour: shade(fallback)
    property color toColour: shade(fallback)
    property bool fromReady: oldWall === ""
    property bool toReady: newWall === ""

    // 0 waiting, 1 fading in, 2 covered (colour shifting), 3 fading out
    property int phase: 0
    property bool shiftDone: false
    property bool liftWanted: false
    property bool wallGone: false

    // A dark shade of a colour: its hue, kept a little vivid, at low light.
    function shade(c) {
        if (c.hslHue < 0) return Qt.hsla(0, 0, 0.11, 1)
        return Qt.hsla(c.hslHue, Math.min(c.hslSaturation, 0.6), 0.13, 1)
    }

    // The main colour of a small copy of a picture: the hue that covers the
    // most of it (vivid, bright pixels count more), averaged within that hue.
    // A grey picture gives its plain average.
    function mainColour(px, n) {
        const bins = 24
        let w = new Array(bins).fill(0), r = new Array(bins).fill(0),
            g = new Array(bins).fill(0), b = new Array(bins).fill(0)
        let ar = 0, ag = 0, ab = 0
        for (let i = 0; i < n; i++) {
            const R = px[i*4] / 255, G = px[i*4+1] / 255, B = px[i*4+2] / 255
            ar += R; ag += G; ab += B
            const mx = Math.max(R, G, B), mn = Math.min(R, G, B), d = mx - mn
            if (mx < 0.08 || d < 0.06) continue
            let h
            if (mx === R) h = ((G - B) / d + 6) % 6
            else if (mx === G) h = (B - R) / d + 2
            else h = (R - G) / d + 4
            const k = Math.floor(h / 6 * bins) % bins
            const wt = (d / mx) * mx            // saturation × brightness
            w[k] += wt; r[k] += R*wt; g[k] += G*wt; b[k] += B*wt
        }
        let best = 0
        for (let k = 1; k < bins; k++) if (w[k] > w[best]) best = k
        if (w[best] < n * 0.02) return Qt.rgba(ar/n, ag/n, ab/n, 1)
        return Qt.rgba(r[best]/w[best], g[best]/w[best], b[best]/w[best], 1)
    }

    function begin() { if (phase === 0) phase = 1 }
    function lift() { liftWanted = true; tryLift() }
    function tryLift() { if (phase === 2 && shiftDone && liftWanted) phase = 3 }

    IpcHandler {
        target: "curtain"
        function lift(): void { root.lift() }
        // "covered" once the old desktop can't be seen any more.
        function state(): string {
            return (root.style === "none" || root.phase >= 2) ? "covered" : "waiting"
        }
    }

    // Start fading in as soon as the old colour is known; don't wait long
    // for it (a broken picture just gives the fallback colour).
    onFromReadyChanged: if (fromReady) startLater.start()
    Timer { id: startLater; interval: 30; onTriggered: root.begin() }
    Timer { interval: 400; running: true; onTriggered: root.begin() }
    Component.onCompleted: { log("loaded"); if (fromReady) startLater.start() }
    function log(m) { if (Quickshell.env("ZX_DEBUG")) console.log(Date.now() % 100000, m) }

    Timer { id: coveredLater; interval: root.fadeIn; onTriggered: root.phase = 2 }
    Timer { id: shiftLater; interval: root.shift; onTriggered: { root.shiftDone = true; root.tryLift() } }
    Timer { interval: 10000; running: true; onTriggered: { root.shiftDone = true; root.lift() } }
    onPhaseChanged: {
        log("phase " + phase)
        if (phase === 1) coveredLater.start()
        if (phase === 2) shiftLater.start()
        if (phase === 3) { quitLater.start(); wallLater.start() }
    }
    // The wallpaper copy goes once the new shell has surely drawn its own.
    Timer { id: wallLater; interval: root.fadeOut + 1500; onTriggered: root.wallGone = true }
    Timer { id: quitLater; interval: root.fadeOut + 2000; onTriggered: Qt.quit() }

    // The colour shown now: the old shade until covered, then sliding to the
    // new one.
    // (Mixed by hand, so a late answer from a colour picker is used at
    // once instead of being animated to.)
    property real mix: phase >= 2 ? 1 : 0
    Behavior on mix { NumberAnimation { duration: root.shift; easing.type: Easing.InOutQuad } }
    readonly property color shown: Qt.rgba(fromColour.r + (toColour.r - fromColour.r) * mix,
                                           fromColour.g + (toColour.g - fromColour.g) * mix,
                                           fromColour.b + (toColour.b - fromColour.b) * mix, 1)

    // The wallpaper copy.
    Variants {
        // Only made once the curtain covers the screen: a new background
        // surface goes on top of the old shell's (a video too), so made
        // earlier it would show through before the fade-in.
        model: root.newWall && root.phase >= 2 ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "zexos-curtain-wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            Image {
                anchors.fill: parent
                source: "file://" + root.newWall
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: root.wallGone ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutCubic } }
            }
        }
    }

    // The curtain.
    Variants {
        model: root.style === "none" ? [] : Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "zexos-curtain"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            // The colour pickers: each loads a tiny copy of a wallpaper
            // (decoded small, so it's quick even for a huge picture), draws
            // it and reads its pixels. Only the first screen's copies are used.
            Repeater {
                model: [ { which: "from", path: root.oldWall }, { which: "to", path: root.newWall } ]
                Canvas {
                    id: picker
                    required property var modelData
                    width: 48; height: 27
                    opacity: 0
                    readonly property string url: modelData.path ? "file://" + modelData.path : ""
                    // Decoded at this tiny size, so it's quick even for a huge picture.
                    Component.onCompleted: if (url) loadImage(url, Qt.size(width, height))
                    onImageLoaded: requestPaint()
                    onPaint: {
                        if (!url || !isImageLoaded(url)) return
                        const ctx = getContext("2d")
                        ctx.drawImage(url, 0, 0, width, height)
                        const d = ctx.getImageData(0, 0, width, height).data
                        give(root.shade(root.mainColour(d, width * height)))
                    }
                    function give(c) {
                        if (modelData.which === "from") { if (!root.fromReady) { root.fromColour = c; root.fromReady = true } }
                        else if (!root.toReady) { root.toColour = c; root.toReady = true }
                    }
                }
            }

            Item {
                anchors.fill: parent
                opacity: root.phase === 1 || root.phase === 2 ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: root.phase === 3 ? root.fadeOut : root.fadeIn; easing.type: Easing.InOutCubic }
                }

                Rectangle { anchors.fill: parent; color: root.shown }

                Image {
                    visible: root.style === "logo" && root.icon !== ""
                    // As tall as nearly half the screen, so it is the first
                    // thing you notice. Sized and placed from the screen, not
                    // the window, so it can't jump while the window settles.
                    readonly property int side: Math.round(win.modelData.height * 0.46)
                    x: Math.round((win.modelData.width - side) / 2)
                    y: Math.round((win.modelData.height - side) / 2)
                    height: side
                    width: side
                    sourceSize: Qt.size(side * 2, side * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
                }
            }
        }
    }
}
