pragma ComponentBehavior: Bound
import QtQuick
import "../theme"

// Reusable hover/press overlay for the right island and power button.
//
// Adapted from Caelestia's StateLayer principle — one primitive expresses
// transient interaction state as a flat fill, never a border — reduced to
// the shapes this shell actually uses today. Ripple/motion variants are a
// later unit (the smooth-motion pilot in unit 2 wired this overlay's opacity
// feedback to the Motion effects intent; ripple variants remain future work).
// Consumers pass their own interaction booleans; this item is a passive
// overlay so input routing stays in the owning component's MouseArea.
Item {
    id: root

    property bool hovered: false
    property bool pressed: false
    property color stateColor: Colors.text
    property real radius: 0
    property real hoverOpacity: Theme.islandStateLayerHoverOpacity
    property real pressedOpacity: Theme.islandStateLayerPressedOpacity

    // Passive overlay: size itself to the owning surface. Without this the
    // root Item stays 0x0 and the state fill is never visible.
    anchors.fill: parent

    // The owner passes its silhouette radius explicitly. This keeps the
    // passive primitive independent of the owner's concrete QML type and
    // avoids a fragile parent.radius lookup through QQuickItem.

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.stateColor
        opacity: root.pressed ? root.pressedOpacity
               : root.hovered ? root.hoverOpacity
               : 0.0

        // Hover/press feedback is the shortest thing in the shell, so it takes
        // the effects intent: no duration or easing literal lives here anymore.
        Behavior on opacity {
            Motion.Effects { }
        }
    }
}
