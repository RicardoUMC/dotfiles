import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

// Metrics dropdown overlay — fullscreen PanelWindow anchored top-right.
// Follows PowerMenu's overlay pattern: fullscreen dismiss MouseArea,
// Escape-to-close, keyboard focus on open. Receives stat data via
// systemStatsState (bound from SystemStats.dataState in Bar.qml).
Item {
    id: root

    implicitWidth: 1
    implicitHeight: 1

    property QtObject systemStatsState: null

    signal opened()
    signal closed()

    function open()   { popup.visible = true }
    function close()  { popup.visible = false; closed() }
    readonly property bool isOpen: popup.visible

    // Replicated from SystemStats.statColor() — avoids cross-file
    // QML function exposure complexity for a 3-line utility.
    function statColor(val) {
        if (val >= 80) return Colors.red
        if (val >= 60) return Colors.yellow
        return Colors.textDim
    }

    PanelWindow {
        id: popup
        visible: false
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: {
            if (visible) {
                keyHandler.forceActiveFocus()
                root.opened()
            }
        }

        // Click anywhere outside the content panel closes the dropdown
        MouseArea {
            anchors.fill: parent
            onClicked: { popup.visible = false; root.closed() }
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    popup.visible = false
                    root.closed()
                    event.accepted = true
                }
            }
        }

        // Content panel anchored to top-right corner (same offset as PowerMenu)
        Rectangle {
            anchors { top: parent.top; right: parent.right }
            anchors { topMargin: Theme.barHeight + Theme.spacingMd - 1; rightMargin: Theme.spacingMd - 1 }
            width: 200
            height: col.implicitHeight + Theme.spacingLg
            radius: Theme.radiusMd
            color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacitySurface)
            border {
                width: 1
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.35)
            }

            // Consume clicks so they don't propagate to the dismiss MouseArea
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: col
                anchors { fill: parent; margins: Theme.spacingSm }
                spacing: Theme.spacingSm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Text { text: "RAM"; color: Colors.blue; font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody } }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: (root.systemStatsState?.ram ?? 0) + "%"
                        color: root.statColor(root.systemStatsState?.ram ?? 0)
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Text { text: "GPU"; color: Colors.magenta; font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody } }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: (root.systemStatsState?.gpu ?? 0) + "%"
                        color: root.statColor(root.systemStatsState?.gpu ?? 0)
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Text { text: "CPU"; color: Colors.orange; font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody } }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: (root.systemStatsState?.cpu ?? 0) + "%"
                        color: root.statColor(root.systemStatsState?.cpu ?? 0)
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Text { text: "DSK"; color: Colors.brown; font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody } }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: (root.systemStatsState?.disk ?? 0) + " MB/s"
                        color: Colors.textDim
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Text { text: "NET"; color: Colors.green; font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody } }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: (root.systemStatsState?.netUp ?? false) ? "ON" : "OFF"
                        color: (root.systemStatsState?.netUp ?? false) ? Colors.green : Colors.red
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Text { text: "VOL"; color: Colors.yellow; font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody } }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: (root.systemStatsState?.muted ?? false) ? "MUTED" : (root.systemStatsState?.volume ?? 0) + "%"
                        color: (root.systemStatsState?.muted ?? false) ? Colors.muted : Colors.textDim
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                    }
                }
            }

            // Debug visual bounds overlay (development scaffolding)
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: Theme.radiusMd
                border {
                    width: Theme.debugBorderWidth
                    color: Theme.debugBorderColor
                }
                visible: Theme.debugVisualBounds
                z: 999
            }
        }
    }
}
