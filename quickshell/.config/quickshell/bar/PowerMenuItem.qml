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
        ? Theme.buttonFill(root.danger ? Colors.red : Colors.accent, root.selected,
                           ma.pressed ? "pressed" : (ma.containsMouse ? "hover" : "rest"))
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

    // Debug visual bounds overlay (development scaffolding)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: parent.radius
        border {
            width: Theme.debugBorderWidth
            color: Theme.debugBorderColor
        }
        visible: Theme.debugVisualBounds
        z: 999
    }
}
