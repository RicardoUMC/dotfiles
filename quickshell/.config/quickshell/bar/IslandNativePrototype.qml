import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._BackgroundEffect

// Stage-2 bounded native-blur feasibility helper. This is an intentionally
// approximate visual surface: its local QRegion describes the bounded island
// envelope, not the authoritative Canvas mask or the input region.
PanelWindow {
    id: root

    required property var screenTarget
    required property real sectionX
    required property real sectionY
    required property real sectionWidth
    required property real sectionHeight
    required property real cornerRadius
    required property real wrapDepth

    screen: screenTarget
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    margins { top: Math.max(0, sectionY); left: Math.max(0, sectionX) }
    implicitWidth: Math.max(0, sectionWidth)
    implicitHeight: Math.max(0, sectionHeight + wrapDepth)
    color: "transparent"

    BackgroundEffect.blurRegion: blurRegion

    // Transparent visual bounds keep this helper passive. The native blur
    // region is deliberately local and bounded to this item's geometry.
    Item {
        id: prototypeBounds
        anchors.fill: parent
    }

    Region {
        id: blurRegion
        item: prototypeBounds
        // Feasibility approximation only: rounded right/bottom edges replace
        // the production Canvas mask and do not claim exact silhouette parity.
        topRightRadius: Math.max(0, cornerRadius)
        bottomRightRadius: Math.max(0, cornerRadius)
    }

    // Explicitly non-interactive and non-focusable input surface.
    mask: Region {}
}
