import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

// Compact icon button for opening the metrics dropdown.
// Emits clicked() — no toggle logic; overlay coordination lives in shell.qml.
Item {
    id: root

    implicitWidth: btn.width
    implicitHeight: btn.height
    Layout.preferredWidth: btn.width
    Layout.preferredHeight: btn.height

    signal clicked()

    Rectangle {
        id: btn
        width: 28
        height: 22
        radius: Theme.radiusSm
        color: mouseBtn.containsMouse
            ? Qt.rgba(Colors.blue.r, Colors.blue.g, Colors.blue.b, Theme.opacityDim)
            : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacityOverlay)
        border {
            width: 1
            color: mouseBtn.containsMouse
                ? Qt.rgba(Colors.blue.r, Colors.blue.g, Colors.blue.b, 0.5)
                : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
        }

        Text {
            anchors.centerIn: parent
            text: "\u2263"  // ≡  — Nerd Font grid icon
            color: mouseBtn.containsMouse ? Colors.blue : Colors.muted
            font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
        }

        MouseArea {
            id: mouseBtn
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.clicked()
        }
    }

    // Debug visual bounds overlay (development scaffolding)
    Rectangle {
        anchors.fill: btn
        color: "transparent"
        radius: Theme.radiusSm
        border {
            width: Theme.debugBorderWidth
            color: Theme.debugBorderColor
        }
        visible: Theme.debugVisualBounds
        z: 999
    }
}
