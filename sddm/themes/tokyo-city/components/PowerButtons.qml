import QtQuick 2.15
import QtQuick.Layouts 1.15

// sddm is a SDDM context global — accessed directly.
Item {
    id: root

    property var colors

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        PowerButton {
            icon: "󰜉"
            label: "Reiniciar"
            colors: root.colors
            onClicked: sddm.reboot()
        }

        PowerButton {
            icon: "󰐥"
            label: "Apagar"
            colors: root.colors
            onClicked: sddm.powerOff()
        }
    }

    component PowerButton: Item {
        id: btn
        property string icon
        property string label
        property var colors
        signal clicked

        implicitWidth: btnRow.implicitWidth + 20
        implicitHeight: 32

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: area.containsMouse
                ? Qt.rgba(btn.colors.muted.r, btn.colors.muted.g, btn.colors.muted.b, 0.15)
                : "transparent"
            border.width: 1
            border.color: area.containsMouse
                ? Qt.rgba(btn.colors.muted.r, btn.colors.muted.g, btn.colors.muted.b, 0.3)
                : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RowLayout {
            id: btnRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                text: btn.icon
                font.family: btn.colors.monoFont
                font.pixelSize: 14
                color: btn.colors.muted
            }

            Text {
                text: btn.label
                font.family: btn.colors.uiFont
                font.pixelSize: 12
                color: btn.colors.muted
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
