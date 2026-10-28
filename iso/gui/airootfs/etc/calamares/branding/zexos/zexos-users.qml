/* Users page (usersq@zexos): one question at a time, in three short steps
 * inside the Users step: your name, a password, then how to log in.
 * Calamares' own users code (config) still checks everything and makes the
 * account; this file is only the look. Next (bottom right) turns on once
 * name and password are valid; the page's own Continue/Back move between
 * the three steps. The colours are the ones zexos-gui-installer swaps for
 * the wallpaper's. */
import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Rectangle {
    id: page
    width: parent.width
    height: parent.height
    color: "#0f0f14"

    property int step: 0
    readonly property var questions: [
        "What's your name?",
        "Choose a password",
        "How do you want to log in?"
    ]
    property bool editNames: false

    // Calamares' own checks: an empty status means "fine".
    readonly property bool nameOk: config.fullName.length > 0 && config.loginName.length > 0
                                   && config.loginNameStatus === "" && config.hostnameStatus === ""
    readonly property bool pwOk: config.userPassword.length > 0 && config.userPasswordValidity !== 2
    readonly property bool canContinue: step === 0 ? nameOk : step === 1 ? pwOk : true

    // A rough 0-4 score for the bar: length plus the kinds of characters used.
    function score(pw) {
        if (pw.length === 0) return 0
        var s = pw.length >= 12 ? 2 : pw.length >= 8 ? 1 : 0
        var kinds = [/[a-z]/, /[A-Z]/, /[0-9]/, /[^A-Za-z0-9]/].filter(function (r) { return r.test(pw) }).length
        s += kinds >= 3 ? 2 : kinds >= 2 ? 1 : 0
        return Math.max(1, Math.min(4, s))
    }
    readonly property var scoreWords: ["", "Weak", "Fair", "Good", "Strong"]
    readonly property var scoreColors: ["#3a3a4c", "#ff6b81", "#f5a97f", "#a78bfa", "#3DDC97"]

    // Enter / Continue: the next of the three steps, and from the last one
    // on to the next page, like Calamares' own Next.
    function next() {
        if (step === 2) { if (config.ready) ViewManager.next(); return }
        if (canContinue) { step++; focusTimer.restart() }
    }
    focus: true
    Keys.onReturnPressed: page.next()
    Keys.onEnterPressed: page.next()
    function back() { if (step > 0) { step--; focusTimer.restart() } }
    Timer { id: focusTimer; interval: 50; onTriggered: (page.step === 0 ? nameField.input : page.step === 1 ? pwField.input : page).forceActiveFocus() }
    Component.onCompleted: focusTimer.restart()
    function onActivate() { focusTimer.restart() }

    // One round box with an icon in front, used for every answer.
    component PillField: Rectangle {
        id: pf
        property alias text: input.text
        property alias input: input
        property string icon: "user"
        property string hint: ""
        property bool masked: false
        property bool shown: false
        Layout.fillWidth: true
        implicitHeight: 52
        radius: height / 2
        color: "#1a1a24"
        border.width: 2
        border.color: input.activeFocus ? "#7C5CFF" : "#22222e"
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Image {
            id: ico
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl("zexos-users-" + pf.icon + ".svg")
            sourceSize.width: 20
            sourceSize.height: 20
            opacity: input.activeFocus ? 1 : 0.7
        }
        TextField {
            id: input
            anchors.left: ico.right
            anchors.leftMargin: 12
            anchors.right: eye.visible ? eye.left : parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: pf.hint
            placeholderTextColor: "#6a6a80"
            color: "#e6e6ef"
            selectionColor: "#7C5CFF"
            font.pixelSize: 17
            echoMode: pf.shown || !pf.masked ? TextInput.Normal : TextInput.Password
            background: null
            Keys.onReturnPressed: page.next()
            Keys.onEnterPressed: page.next()
        }
        Image {
            id: eye
            visible: pf.masked
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl(pf.shown ? "zexos-users-eye-off.svg" : "zexos-users-eye.svg")
            sourceSize.width: 20
            sourceSize.height: 20
            opacity: eyeArea.containsMouse ? 1 : 0.7
            MouseArea {
                id: eyeArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pf.shown = !pf.shown
            }
        }
    }

    // The red / orange / green line under a box.
    component Note: Text {
        property string kind: "bad"   // bad | warn | good
        Layout.fillWidth: true
        Layout.leftMargin: 22
        visible: text.length > 0
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: kind === "good" ? "#3DDC97" : kind === "warn" ? "#f5a97f" : "#ff6b81"
    }

    // An on/off switch row.
    component SwitchRow: Rectangle {
        id: sr
        property string title: ""
        property string detail: ""
        property bool on: false
        signal toggled()
        Layout.fillWidth: true
        implicitHeight: srCol.implicitHeight + 30
        radius: 16
        color: srArea.containsMouse ? "#20202c" : "#1a1a24"
        border.width: 2
        border.color: "#22222e"
        ColumnLayout {
            id: srCol
            anchors.left: parent.left
            anchors.right: knob.left
            anchors.leftMargin: 20
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text { text: sr.title; color: "#e6e6ef"; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Text { text: sr.detail; color: "#9a9ab0"; font.pixelSize: 14; Layout.fillWidth: true; wrapMode: Text.WordWrap; visible: text.length > 0 }
        }
        Rectangle {
            id: knob
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 50; height: 28; radius: 14
            color: sr.on ? "#7C5CFF" : "#3a3a4c"
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                width: 20; height: 20; radius: 10
                y: 4
                x: sr.on ? parent.width - width - 4 : 4
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea {
            id: srArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sr.toggled()
        }
    }

    ColumnLayout {
        id: column
        width: Math.min(560, parent.width - 56)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        // ZeXOS logo and title
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "file:/" + Branding.imagePath(Branding.ProductLogo)
            sourceSize.width: 64
            sourceSize.height: 64
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Set up your ZeXOS account"
            color: "#9a9ab0"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        // Step counter: three dots and "Step 1 of 3"
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            spacing: 8
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    implicitWidth: index === page.step ? 26 : 9
                    implicitHeight: 9
                    radius: 4.5
                    color: index <= page.step ? "#7C5CFF" : "#3a3a4c"
                    Behavior on implicitWidth { NumberAnimation { duration: 160 } }
                }
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "STEP " + (page.step + 1) + " OF 3"
            color: "#6a6a80"
            font.pixelSize: 12
            font.letterSpacing: 1.6
            font.weight: Font.DemiBold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 10
            text: page.questions[page.step]
            color: "#ffffff"
            font.pixelSize: 32
            font.weight: Font.Bold
        }

        // ---- Step 1: your name ----
        ColumnLayout {
            visible: page.step === 0
            Layout.fillWidth: true
            spacing: 10
            PillField {
                id: nameField
                icon: "user"
                hint: "Your full name"
                text: config.fullName
                input.onTextChanged: if (input.text !== config.fullName) config.setFullName(input.text)
            }
            // Username and computer name, filled in from the name.
            Flow {
                visible: !page.editNames && config.loginName.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 22
                spacing: 8
                Text { text: "Username"; color: "#9a9ab0"; font.pixelSize: 14; height: 26; verticalAlignment: Text.AlignVCenter }
                Rectangle {
                    height: 26; radius: 13; width: u.implicitWidth + 20; color: "#22222e"
                    Text { id: u; anchors.centerIn: parent; text: config.loginName; color: "#e6e6ef"; font.pixelSize: 14 }
                }
                Text { text: "·  Computer"; color: "#9a9ab0"; font.pixelSize: 14; height: 26; verticalAlignment: Text.AlignVCenter }
                Rectangle {
                    height: 26; radius: 13; width: h.implicitWidth + 20; color: "#22222e"
                    Text { id: h; anchors.centerIn: parent; text: config.hostname; color: "#e6e6ef"; font.pixelSize: 14 }
                }
                Text {
                    text: "Change"; color: "#a78bfa"; font.pixelSize: 14; font.weight: Font.DemiBold
                    height: 26; verticalAlignment: Text.AlignVCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: page.editNames = true }
                }
            }
            PillField {
                visible: page.editNames
                icon: "user"
                hint: "Username"
                text: config.loginName
                input.onTextChanged: if (input.text !== config.loginName) config.setLoginName(input.text)
            }
            Note { text: config.loginNameStatus }
            PillField {
                visible: page.editNames
                icon: "pc"
                hint: "Computer name"
                text: config.hostname
                input.onTextChanged: if (input.text !== config.hostname) config.setHostName(input.text)
            }
            Note { text: config.hostnameStatus }
        }

        // ---- Step 2: the password, typed twice, with the strength bar ----
        ColumnLayout {
            visible: page.step === 1
            Layout.fillWidth: true
            spacing: 10
            PillField {
                id: pwField
                icon: "lock"
                masked: true
                hint: "Pick one you'll remember"
                text: config.userPassword
                input.onTextChanged: if (input.text !== config.userPassword) config.setUserPassword(input.text)
            }
            PillField {
                icon: "lock"
                masked: true
                hint: "Type it again"
                text: config.userPasswordSecondary
                input.onTextChanged: if (input.text !== config.userPasswordSecondary) config.setUserPasswordSecondary(input.text)
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 22
                Layout.rightMargin: 22
                Layout.topMargin: 4
                spacing: 6
                visible: config.userPassword.length > 0
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        readonly property int s: page.score(config.userPassword)
                        color: index < s ? page.scoreColors[s] : "#2a2a38"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                Text {
                    Layout.leftMargin: 8
                    text: page.scoreWords[page.score(config.userPassword)]
                    color: page.scoreColors[page.score(config.userPassword)]
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }
            Note {
                // Calamares says "OK!" when all is well; show that as "Passwords match".
                text: config.userPassword.length === 0 ? "" :
                      config.userPasswordValidity === 0 ? (config.userPasswordSecondary.length ? "Passwords match" : "") :
                      config.userPasswordMessage
                kind: config.userPasswordValidity === 0 ? "good" : config.userPasswordValidity === 1 ? "warn" : "bad"
            }
        }

        // ---- Step 3: how to log in ----
        ColumnLayout {
            visible: page.step === 2
            Layout.fillWidth: true
            spacing: 10
            SwitchRow {
                title: "Log in automatically"
                detail: "Start straight on the desktop without typing your password."
                on: config.doAutoLogin
                onToggled: config.setAutoLogin(!config.doAutoLogin)
            }
            SwitchRow {
                visible: config.writeRootPassword
                title: "Use the same password for the admin account"
                detail: "The admin (root) account is for fixing the system. Turn this off to give it its own."
                on: config.reuseUserPasswordForRoot
                onToggled: config.setReuseUserPasswordForRoot(!config.reuseUserPasswordForRoot)
            }
            PillField {
                visible: config.writeRootPassword && !config.reuseUserPasswordForRoot
                icon: "lock"
                masked: true
                hint: "Admin account's own"
                text: config.rootPassword
                input.onTextChanged: if (input.text !== config.rootPassword) config.setRootPassword(input.text)
            }
            PillField {
                visible: config.writeRootPassword && !config.reuseUserPasswordForRoot
                icon: "lock"
                masked: true
                hint: "Type it again"
                text: config.rootPasswordSecondary
                input.onTextChanged: if (input.text !== config.rootPasswordSecondary) config.setRootPasswordSecondary(input.text)
            }
            Note {
                visible: config.writeRootPassword && !config.reuseUserPasswordForRoot && config.rootPassword.length > 0
                text: config.rootPasswordValidity === 0 ? (config.rootPasswordSecondary.length ? "Passwords match" : "") : config.rootPasswordMessage
                kind: config.rootPasswordValidity === 0 ? "good" : config.rootPasswordValidity === 1 ? "warn" : "bad"
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: config.ready
                text: "All set. Press Next to look over everything before installing."
                color: "#3DDC97"
                font.pixelSize: 15
            }
        }

        // Continue / Back between the three steps
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            Text {
                visible: page.step > 0
                text: "‹  Back"
                color: "#a78bfa"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: page.back() }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: page.step < 2
                implicitWidth: cont.implicitWidth + 48
                implicitHeight: 46
                radius: 23
                color: page.canContinue ? (contArea.containsMouse ? "#a78bfa" : "#7C5CFF") : "#2a2a38"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    id: cont
                    anchors.centerIn: parent
                    text: "Continue"
                    color: page.canContinue ? "#ffffff" : "#6a6a80"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: contArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: page.canContinue ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: page.next()
                }
            }
        }
    }
}
