import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"

Item {
    id: root

    implicitWidth: btn.width
    implicitHeight: btn.height

    signal onOpened()
    function close() { popup.visible = false }
    function open() { popup.selectedIndex = 0; popup.visible = true; onOpened() }
    readonly property bool isOpen: popup.visible

    Rectangle {
        id: btn
        width: 28
        height: 22
        radius: Theme.radiusSm
        color: mouseBtn.containsMouse
            ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, Theme.opacityDim)
            : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacityOverlay)
        border {
            width: 1
            color: mouseBtn.containsMouse
                ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.5)
                : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
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
            onClicked: popup.visible ? root.close() : root.open()
        }
    }

    // Fullscreen PanelWindow in Overlay — manages its own outside-click dismissal.
    // No external backdrop needed for the PowerMenu.
    PanelWindow {
        id: popup
        visible: false
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: if (visible) keyHandler.forceActiveFocus()

        property int selectedIndex: 0
        readonly property int itemCount: 3

        // Click anywhere outside the menu content closes the popup
        MouseArea {
            anchors.fill: parent
            onClicked: popup.visible = false
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                const key = event.key
                if (key === Qt.Key_J || key === Qt.Key_Down) {
                    popup.selectedIndex = (popup.selectedIndex + 1) % popup.itemCount
                    event.accepted = true
                } else if (key === Qt.Key_K || key === Qt.Key_Up) {
                    popup.selectedIndex = (popup.selectedIndex - 1 + popup.itemCount) % popup.itemCount
                    event.accepted = true
                } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                    actions[popup.selectedIndex]()
                    event.accepted = true
                } else if (key === Qt.Key_Escape) {
                    popup.visible = false
                    event.accepted = true
                }
            }

            // Matches order of PowerMenuItems below
            property var actions: [
                () => { popup.visible = false; rebootCmd.running = true },
                () => { popup.visible = false; poweroffCmd.running = true },
                () => { popup.visible = false; logoutCmd.running = true }
            ]
        }

        // Menu content anchored to top-right corner
        Rectangle {
            anchors { top: parent.top; right: parent.right }
            anchors { topMargin: Theme.barHeight + Theme.spacingMd - 1; rightMargin: Theme.spacingMd - 1 }
            width: 160
            height: col.implicitHeight + Theme.spacingLg
            radius: Theme.radiusMd
            color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacitySurface)
            border {
                width: 1
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.35)
            }

            // Consume clicks so they don't propagate to the fullscreen dismiss MouseArea
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: col
                anchors { fill: parent; margins: Theme.spacingSm }
                spacing: Theme.spacingXs

                PowerMenuItem {
                    icon: "󰜉"
                    label: "Reiniciar"
                    selected: popup.selectedIndex === 0
                    onActivated: { popup.visible = false; rebootCmd.running = true }
                }

                PowerMenuItem {
                    icon: "󰐥"
                    label: "Apagar"
                    danger: true
                    selected: popup.selectedIndex === 1
                    onActivated: { popup.visible = false; poweroffCmd.running = true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.2)
                }

                PowerMenuItem {
                    icon: "󰍃"
                    label: "Cerrar sesión"
                    selected: popup.selectedIndex === 2
                    onActivated: { popup.visible = false; logoutCmd.running = true }
                }
            }
        }
    }

    Process { id: rebootCmd;  command: ["systemctl", "reboot"] }
    Process { id: poweroffCmd; command: ["systemctl", "poweroff"] }
    Process { id: logoutCmd;  command: ["hyprctl", "dispatch", "exit"] }
}
