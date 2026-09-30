import QtQuick
import Quickshell
import Quickshell.Wayland

// Invisible catcher for the in-place center notch expansion.
Item {
    id: root

    property real centerX: 0
    property real centerWidth: 0
    property real centerHeight: 0

    // Wayland output this overlay pins itself to, passed down from the Bar
    // instance that owns it. An unpinned layer-shell surface sends a null
    // wl_output to get_layer_surface, so the compositor picks the screen.
    property var screenTarget: null

    signal opened()
    signal closed()

    function open() {
        if (popup.visible) return
        popup.visible = true
        opened()
    }

    function close() {
        if (!popup.visible) return
        popup.visible = false
        closed()
    }

    readonly property bool isOpen: popup.visible

    PanelWindow {
        id: popup
        visible: false
        // Null keeps the compositor-picks-output default; a screen pins it.
        screen: root.screenTarget
        color: "transparent"

        // Layer rule: transient system feedback (toasts, OSD) owns Overlay; interactive panels are Top.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region { item: centerHole; intersection: Intersection.Xor }

        onVisibleChanged: if (visible) keyHandler.forceActiveFocus()

        // Input pass-through hole over the in-place center element. The catcher
        // stays clickable everywhere else, but controls inside the expanded
        // notch keep receiving their own clicks.
        Item {
            id: centerHole
            x: root.centerX
            y: 0
            width: root.centerWidth
            height: root.centerHeight
        }

        // Click outside the expanded center element closes it.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        // Keyboard handler — Escape closes the panel
        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }
        }

    }
}
