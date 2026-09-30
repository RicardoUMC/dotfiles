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
        // Layout.preferredWidth/Height: this Rectangle is a real ColumnLayout child
        // and carries Layout.alignment: Qt.AlignHCenter, so the layout never stretches
        // it on either axis - it hands the item exactly its preferred size and centers
        // that slot. Feeding 88/88 through the preferred properties reproduces the old
        // plain width/height pixel-for-pixel, which also keeps radius: 44 a true circle
        // (half of 88); a stretched or collapsed slot would have broken it.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 88
            Layout.preferredHeight: 88
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
            font.family: root.colors.uiFont
            font.pixelSize: 17
            font.weight: Font.DemiBold
            color: root.colors.text
        }
    }
}
