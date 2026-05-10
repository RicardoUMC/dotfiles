import QtQuick 2.15
import QtQuick.Layouts 1.15

// sessionModel is a SDDM context global — accessed directly.
Item {
    id: root

    property var colors

    // currentIndex is read by Main.qml to pass to sddm.login()
    property int currentIndex: sessionModel.lastIndex

    readonly property string currentName: sessionModel.data(sessionModel.index(currentIndex, 0), Qt.DisplayRole) ?? "Hyprland"

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰧩"
            font.family: root.colors.monoFont
            font.pixelSize: 13
            color: root.colors.muted
        }

        Text {
            text: root.currentName
            font.family: root.colors.monoFont
            font.pixelSize: 12
            color: root.colors.muted
        }

        Text {
            text: ""
            font.family: root.colors.monoFont
            font.pixelSize: 11
            color: root.colors.muted
            opacity: 0.7
            visible: sessionModel.count > 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentIndex = (root.currentIndex + 1) % sessionModel.count
            }
        }
    }
}
