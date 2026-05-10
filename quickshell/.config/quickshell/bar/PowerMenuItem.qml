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
    radius: 6

    color: (ma.containsMouse || root.selected)
        ? danger
            ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.18)
            : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
        : "transparent"

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 10

        Text {
            text: root.icon
            color: root.danger ? Colors.red : Colors.muted
            font { family: Colors.monoFont; pixelSize: 14 }
        }

        Text {
            text: root.label
            color: (ma.containsMouse || root.selected)
                ? (root.danger ? Colors.red : Colors.text)
                : Colors.textDim
            font { family: Colors.monoFont; pixelSize: 12 }
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
