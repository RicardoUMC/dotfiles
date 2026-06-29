import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto
    implicitHeight: Theme.barRailHeight + Math.max(leftTab.implicitHeight, centerTab.implicitHeight, rightTab.implicitHeight)
    margins { top: 0; left: 0; right: 0 }
    color: "transparent"

    // IPC signals
    signal powerMenuOpened()
    signal powerMenuClosed()
    signal mprisToggleRequested()
    signal mprisClosed()
    signal metricsOpened()
    signal metricsClosed()
    signal metricsToggleRequested()
    signal centerPanelToggleRequested()
    signal centerPanelOpened()
    signal centerPanelClosed()

    // IPC functions
    function closePowerMenu() { powerMenu.close() }
    function openPowerMenu()  { powerMenu.open() }
    function closeMpris()     { mprisPopup.close() }
    function openMetrics()    { metricsDropdown.open() }
    function closeMetrics()   { metricsDropdown.close() }
    function openMpris() {
        mprisPopup.anchorX = centerTab.x + centerTab.width / 2
        mprisPopup.open()
    }
    function setMprisAnchor() {
        mprisPopup.anchorX = centerTab.x + centerTab.width / 2
    }
    function openCenterPanel()  { centerPanel.open() }
    function closeCenterPanel() { centerPanel.close() }

    // IPC readonly properties
    readonly property bool powerMenuVisible: powerMenu.isOpen
    readonly property real powerBtnGlobalX:  rightTab.x + rightTab.width - powerMenu.implicitWidth - Theme.tabPaddingH
    readonly property real mprisChipGlobalX: centerTab.x + centerTab.width / 2
    readonly property real mprisChipWidth:   mprisChip.width
    readonly property bool mprisChipActive:  mprisChip.active
    readonly property bool mprisVisible:     mprisPopup.isOpen

    // Top rail — thin full-width bar anchored to top
    Rectangle {
        id: rail
        z: 0
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Theme.barRailHeight
        topLeftRadius:     Theme.tabRadius
        topRightRadius:    Theme.tabRadius
        bottomLeftRadius:  0
        bottomRightRadius: 0
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.tabBgOpacity)
        border {
            width: 1
            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.islandBorderOpacity)
        }
    }

    // Debug visual bounds overlay for rail (development scaffolding)
    Rectangle {
        anchors.fill: rail
        color: "transparent"
        topLeftRadius:     Theme.tabRadius
        topRightRadius:    Theme.tabRadius
        bottomLeftRadius:  0
        bottomRightRadius: 0
        border {
            width: Theme.debugBorderWidth
            color: Theme.debugBorderColor
        }
        visible: Theme.debugVisualBounds
        z: 999
    }

    // Left tab — Workspaces
    BarTab {
        id: leftTab
        z: 1
        compact: true
        anchors {
            left: parent.left
            top: rail.bottom
            topMargin: 0
        }

        Workspaces {}
    }

    // Center tab — Clock always visible + MPRIS chip inside when active.
    // Fixed at 360px width (no in-place expansion). Clicking emits a toggle
    // signal that opens the floating CenterPanel overlay.
    BarTab {
        id: centerTab
        z: 2
        accentBorder: true
        width: 360
        paddingH: Theme.spacingXl
        paddingV: Theme.spacingSm
        bgOpacity: 0.98
        borderOpacity: 0.42
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: rail.bottom
            topMargin: 0
        }

        ClockChip { expanded: false }

        MprisIndicator {
            id: mprisChip
            visible: active
            onClicked: root.mprisToggleRequested()
        }
    }

    MouseArea {
        anchors.fill: centerTab
        onClicked: root.centerPanelToggleRequested()
        z: 1
    }

    // Right tab — MetricsButton + PowerMenu button
    BarTab {
        id: rightTab
        z: 1
        compact: true
        anchors {
            right: parent.right
            top: rail.bottom
            topMargin: 0
        }

        SystemStats { id: statsEngine }

        MetricsButton {
            onClicked: root.metricsToggleRequested()
        }

        PowerMenu {
            id: powerMenu
            onOnOpened: root.powerMenuOpened()
            onOnClosed: root.powerMenuClosed()
        }
    }

    MetricsDropdown {
        id: metricsDropdown
        systemStatsState: statsEngine.dataState
        onOpened: root.metricsOpened()
        onClosed: root.metricsClosed()
    }

    MprisPopup {
        id: mprisPopup
        onClosed: root.mprisClosed()
    }

    CenterPanel {
        id: centerPanel
        onOpened: root.centerPanelOpened()
        onClosed: root.centerPanelClosed()
    }
}
