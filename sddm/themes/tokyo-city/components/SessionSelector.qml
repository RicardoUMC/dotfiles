import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var colors
    property var sessionModel
    property int currentIndex: 0

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
            visible: root.sessionModel.count > 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentIndex = (root.currentIndex + 1) % root.sessionModel.count
            }
        }
    }
}
