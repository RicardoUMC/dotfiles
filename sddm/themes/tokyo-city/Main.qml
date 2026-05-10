import QtQuick 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0
import "components"
import "theme"

Item {
    id: root

    // SDDM-injected globals
    property var sddm
    property var userModel
    property var sessionModel
    property var config

    readonly property string wallpaper: config.stringValue("Wallpaper") ?? ""
    property bool loggingIn: false

    // Palette instance — passed down to all components
    Colors { id: colors }

    // ── Background ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: colors.background

        Image {
            anchors.fill: parent
            source: root.wallpaper !== "" ? root.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            visible: root.wallpaper !== ""

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.45)
            }
        }
    }

    // ── Clock — top right ───────────────────────────────────────────────
    Clock {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 32
            rightMargin: 40
        }
        colors: colors
    }

    // ── Center panel ────────────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        UserCard {
            id: userCard
            Layout.alignment: Qt.AlignHCenter
            userModel: root.userModel
            colors: colors
        }

        PasswordField {
            id: passwordField
            Layout.alignment: Qt.AlignHCenter
            colors: colors

            property bool _attempted: false

            onAccepted: password => {
                _attempted = true
                root.loggingIn = true
                sddm.login(userCard.currentName, password, sessionSelector.currentIndex)
            }

            Component.onCompleted: focusInput()
        }
    }

    // ── Session selector — bottom left ──────────────────────────────────
    SessionSelector {
        id: sessionSelector
        anchors {
            bottom: parent.bottom
            left: parent.left
            bottomMargin: 28
            leftMargin: 32
        }
        sessionModel: root.sessionModel
        colors: colors
    }

    // ── Power buttons — bottom right ────────────────────────────────────
    PowerButtons {
        anchors {
            bottom: parent.bottom
            right: parent.right
            bottomMargin: 24
            rightMargin: 32
        }
        sddm: root.sddm
        colors: colors
    }

    // ── SDDM callbacks ──────────────────────────────────────────────────
    Connections {
        target: sddm

        function onLoginFailed() {
            root.loggingIn = false
            passwordField.failed = true
            passwordField.clear()
            passwordField.focusInput()
        }

        function onLoginSucceeded() {
            root.loggingIn = false
        }
    }
}
