import QtQuick
import "../theme"

// Immediate power sibling trigger for the right control center. This component
// renders only the destructive pill button; its menu content now lives inside
// RightControlCenter, which owns the in-surface tree for the power section.
// The pill emits intent upward and never opens or closes a surface itself.
Item {
    id: root

    implicitWidth: btn.width
    implicitHeight: btn.height

    signal toggleRequested()

    // Power is a destructive session action, not a service chip: it takes a
    // pill silhouette with a resting red tint instead of the service chips'
    // variable-radius tiles.
    Rectangle {
        id: btn
        width: 28
        height: Theme.barChipHeight
        radius: height / 2
        color: Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b,
                        Theme.islandPowerTintOpacity)

        // Transient feedback under the icon, riding on the resting tint;
        // inherits the pill radius.
        StateLayer {
            hovered: mouseBtn.containsMouse && !mouseBtn.pressed
            pressed: mouseBtn.pressed
            stateColor: Colors.red
            radius: btn.radius
        }

        Text {
            anchors.centerIn: parent
            text: "⏻"
            color: mouseBtn.containsMouse ? Colors.red : Colors.muted
            font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
        }

        MouseArea {
            id: mouseBtn
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.toggleRequested()
        }
    }
}
