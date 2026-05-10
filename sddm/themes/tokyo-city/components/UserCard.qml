import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var colors
    property var userModel
    property int currentIndex: 0

    readonly property string currentName: userModel.data(userModel.index(currentIndex, 0), Qt.UserRole + 1) ?? ""
    readonly property string currentIcon: userModel.data(userModel.index(currentIndex, 0), Qt.UserRole + 3) ?? ""

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

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: root.currentIcon !== "" ? "file://" + root.currentIcon : ""
                fillMode: Image.PreserveAspectCrop
                visible: root.currentIcon !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "󰀄"
                font.family: root.colors.monoFont
                font.pixelSize: 40
                color: root.colors.muted
                visible: root.currentIcon === ""
            }
        }

        // Username with prev/next arrows if more than one user
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Text {
                text: ""
                font.family: root.colors.monoFont
                font.pixelSize: 14
                color: root.colors.muted
                visible: root.userModel.count > 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentIndex = (root.currentIndex - 1 + root.userModel.count) % root.userModel.count
                }
            }

            Text {
                text: root.currentName
                font.family: root.colors.monoFont
                font.pixelSize: 16
                font.bold: true
                color: root.colors.text
            }

            Text {
                text: ""
                font.family: root.colors.monoFont
                font.pixelSize: 14
                color: root.colors.muted
                visible: root.userModel.count > 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentIndex = (root.currentIndex + 1) % root.userModel.count
                }
            }
        }
    }
}
