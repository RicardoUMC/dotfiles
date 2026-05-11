import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool danger: false
    property bool selected: false

    signal activated()

    Layout.fillWidth: true
    implicitHeight: 34
    radius: Theme.radiusSm

    color: (ma.containsMouse || root.selected)
        ? danger
            ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.18)
            : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
        : "transparent"

    RowLayout {
        anchors { fill: parent; leftMargin: Theme.spacingMd - 2; rightMargin: Theme.spacingMd - 2 }
        spacing: Theme.spacingSm + 2

        Text {
            text: root.icon
            color: root.danger ? Colors.red : Colors.muted
            font { family: Colors.monoFont; pixelSize: Theme.fontSizeBodyLg }
        }

        Text {
            text: root.label
            color: (ma.containsMouse || root.selected)
                ? (root.danger ? Colors.red : Colors.text)
                : Colors.textDim
            font { family: Colors.uiFont; pixelSize: 12 }
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
    }
}
