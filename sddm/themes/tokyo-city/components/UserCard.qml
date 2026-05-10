import QtQuick 2.15
import QtQuick.Layouts 1.15

// Displays the last logged-in user's avatar and name.
// userModel is a SDDM context global — accessed directly, not passed as prop.
Item {
    id: root

    property var colors

    // currentName is read by Main.qml to pass to sddm.login()
    readonly property string currentName: userModel.lastUser

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 12

        // Avatar
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 88
            height: 88
            radius: 44
            color: root.colors.surface
            border.width: 2
            border.color: Qt.rgba(root.colors.accent.r, root.colors.accent.g, root.colors.accent.b, 0.5)

            Text {
                anchors.centerIn: parent
                text: "󰀄"
                font.family: root.colors.monoFont
                font.pixelSize: 40
                color: root.colors.muted
            }
        }

        // Username
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.currentName
            font.family: root.colors.monoFont
            font.pixelSize: 16
            font.bold: true
            color: root.colors.text
        }
    }
}
