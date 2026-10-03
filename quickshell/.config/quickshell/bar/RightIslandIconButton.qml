import QtQuick
import QtQuick.Layouts
import "../theme"

// Right-island service chip. State is expressed through fill and icon accent
// (adapted from Caelestia's state-layer grammar), never through a per-chip
// outline: the silhouette behind these chips already carries the edge, and a
// border on every chip reads as "empty" regardless of service state.
//
// Visual grammar:
//   - service off           quiet base01 fill, muted icon
//   - on / not connected    quiet base01 fill, dim icon
//   - active (connected/    accent-tinted fill + accent icon
//     unmuted / has recents)
//   - warning (muted, DND)  orange-tinted fill + orange icon (warning wins)
//   - hover / pressed       StateLayer overlay on top of the state fill
// Click routing is unchanged: the consumer owns the semantics via `clicked`.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    // True when the backing service is switched off (adapter disabled). Takes
    // visual precedence over `active` so a disabled radio never reads as live.
    property bool disabled: false
    property bool active: false
    property bool warning: false
    property color accentColor: warning ? Colors.orange : Colors.accent

    signal clicked()

    Layout.preferredWidth: 28
    implicitWidth: 28
    implicitHeight: Theme.barChipHeight
    radius: Theme.islandChipRadius

    color: root.disabled
           ? Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacityDim)
           : (root.active || root.warning)
           ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b,
                     Theme.islandActiveFillOpacity)
           : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacityOverlay)

    // Service state is what this fill encodes, and it can flip while the chip is
    // on screen (Wi-Fi connected/disconnected, audio muted/unmuted). A fill that
    // changes color in one frame reads as a glitch, so state transitions take the
    // effects intent. The icon color below is deliberately NOT animated: it reacts
    // to hover, and delaying pointer feedback would make the chip feel laggy.
    Behavior on color {
        Motion.EffectsColor { }
    }

    // Transient hover/press feedback under the icon; inherits this chip's
    // radius so it never fights the silhouette.
    StateLayer {
        hovered: buttonArea.containsMouse && !buttonArea.pressed
        pressed: buttonArea.pressed
        stateColor: root.disabled ? Colors.muted : root.accentColor
        radius: root.radius
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.disabled ? Colors.muted
               : (root.active || root.warning || buttonArea.containsMouse) ? root.accentColor
               : Colors.textDim
        font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
    }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
