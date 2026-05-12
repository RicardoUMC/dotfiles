import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto
    implicitHeight: Theme.barHeightIslands
    margins { top: 0; left: 0; right: 0 }
    color: "transparent"

    // IPC signals
    signal powerMenuOpened()
    signal powerMenuClosed()
    signal mprisToggleRequested()
    signal mprisClosed()

    // IPC functions
    function closePowerMenu() { powerMenu.close() }
    function openPowerMenu()  { powerMenu.open() }
    function closeMpris()     { mprisPopup.close() }
    function openMpris()      { mprisPopup.open() }
    function setMprisAnchor() {
        mprisPopup.anchorX = mprisChip.x + centerIsland.x + mprisChip.width / 2
    }

    // IPC readonly properties
    readonly property bool powerMenuVisible: powerMenu.isOpen
    readonly property real powerBtnGlobalX:  rightIsland.x + rightIsland.width - powerMenu.implicitWidth - Theme.islandPaddingH
    readonly property real mprisChipGlobalX: centerIsland.x + Theme.islandPaddingH
    readonly property real mprisChipWidth:   mprisChip.width
    readonly property bool mprisChipActive:  mprisChip.active
    readonly property bool mprisVisible:     mprisPopup.isOpen

    // Decorative ornament layer — behind everything
    Shape {
        anchors.fill: parent
        z: -1

        ShapePath {
            strokeColor: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.ornamentOpacity)
            strokeWidth: Theme.ornamentStroke
            fillColor: "transparent"
            startX: 0; startY: parent.height * 0.6
            PathCubic {
                x: parent.width * 0.5; y: parent.height * 0.2
                control1X: parent.width * 0.15; control1Y: parent.height * 0.1
                control2X: parent.width * 0.35; control2Y: parent.height * 0.05
            }
            PathCubic {
                x: parent.width; y: parent.height * 0.5
                control1X: parent.width * 0.65; control1Y: parent.height * 0.35
                control2X: parent.width * 0.85; control2Y: parent.height * 0.6
            }
        }

        ShapePath {
            strokeColor: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.ornamentOpacity)
            strokeWidth: Theme.ornamentStroke
            fillColor: "transparent"
            startX: parent.width * 0.2; startY: 0
            PathCubic {
                x: parent.width * 0.8; y: parent.height
                control1X: parent.width * 0.4;  control1Y: parent.height * 0.3
                control2X: parent.width * 0.6;  control2Y: parent.height * 0.7
            }
        }
    }

    // Left island — Workspaces
    BarIsland {
        id: leftIsland
        spacing: 0
        anchors {
            left: parent.left
            leftMargin: Theme.spacingMd
            verticalCenter: parent.verticalCenter
        }

        Workspaces {}
    }

    // Center island — MPRIS (visible only when active)
    BarIsland {
        id: centerIsland
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }
        visible: mprisChip.active

        MprisIndicator {
            id: mprisChip
            onClicked: root.mprisToggleRequested()
        }
    }

    // Right island — SystemStats + ClockChip + PowerMenu
    BarIsland {
        id: rightIsland
        anchors {
            right: parent.right
            rightMargin: Theme.spacingMd
            verticalCenter: parent.verticalCenter
        }

        SystemStats {}
        ClockChip {}

        PowerMenu {
            id: powerMenu
            onOnOpened: root.powerMenuOpened()
            onOnClosed: root.powerMenuClosed()
        }
    }

    MprisPopup {
        id: mprisPopup
        onClosed: root.mprisClosed()
    }
}
