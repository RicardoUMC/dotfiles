import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto
    implicitHeight: Math.max(leftTab.implicitHeight, centerTab.implicitHeight, rightTab.implicitHeight)
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

    // Composed segment geometry (replaces old ShapePath silhouette)
    // All three lower segments share equal notch depth in base normal state.
    // The gaps between segments create concave notch openings where the
    // transparent PanelWindow background shows through.
    readonly property real notchDepth: root.height * Theme.barNotchDepthRatio
    readonly property real connectorHeight: root.height - notchDepth
    readonly property real gapHalf: Theme.barNotchGapWidth / 2

    // Segment fill: normal base01 or high-contrast debug red
    readonly property color segmentFill: Theme.debugBarSilhouette
        ? Qt.rgba(1.0, 0.2, 0.2, 0.65)
        : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.tabBgOpacity)

    readonly property int segmentBorderWidth: Theme.debugBarSilhouette ? 1 : 0
    readonly property color segmentBorderColor: Theme.debugBarSilhouette ? "#ff3344" : "transparent"

    // --- Composed silhouette: 3 bottom segments + top connector strip ---
    // All segments share the same visual height (notchDepth) per spec R4.
    // Gaps between segments at section boundaries expose transparent
    // PanelWindow background, creating the concave notch visual.
    // Top connector (z:0) spans full width above the notch zone.

    // Left segment — equal depth with center and right.
    // bottomLeftRadius: 0 keeps outer edge square per design decision.
    Rectangle {
        id: leftSegment
        y: root.connectorHeight
        x: 0
        width: centerTab.x - gapHalf
        height: root.notchDepth
        visible: Theme.barStyle === "silhouette"
        color: root.segmentFill
        border { width: root.segmentBorderWidth; color: root.segmentBorderColor }
        radius: 0
        bottomLeftRadius: 0
        bottomRightRadius: Theme.tabRadius
        z: 0
    }

    // Center segment — equal depth with left/right in base normal state.
    // (Future expanded/open state may use a deeper/taller center overlay,
    // but the base normal silhouette is uniform height.)
    Rectangle {
        id: centerSegment
        y: root.connectorHeight
        x: centerTab.x + gapHalf
        width: centerTab.width - Theme.barNotchGapWidth
        height: root.notchDepth
        visible: Theme.barStyle === "silhouette"
        color: root.segmentFill
        border { width: root.segmentBorderWidth; color: root.segmentBorderColor }
        radius: 0
        bottomLeftRadius: Theme.tabRadius
        bottomRightRadius: Theme.tabRadius
        z: 0
    }

    // Right segment — equal depth with left and center.
    // bottomRightRadius: 0 keeps outer edge square.
    Rectangle {
        id: rightSegment
        y: root.connectorHeight
        x: centerTab.x + centerTab.width + gapHalf
        width: parent.width - x
        height: root.notchDepth
        visible: Theme.barStyle === "silhouette"
        color: root.segmentFill
        border { width: root.segmentBorderWidth; color: root.segmentBorderColor }
        radius: 0
        bottomLeftRadius: Theme.tabRadius
        bottomRightRadius: 0
        z: 0
    }

    // Top connector strip — full-width, sits above the notch zone.
    // Square outer corners per design decision.
    Rectangle {
        id: topConnector
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.connectorHeight
        visible: Theme.barStyle === "silhouette"
        color: root.segmentFill
        border { width: root.segmentBorderWidth; color: root.segmentBorderColor }
        radius: 0
        z: 0
    }

    // Left tab — Workspaces
    BarTab {
        id: leftTab
        z: 1
        compact: true
        anchors {
            left: parent.left
            top: parent.top
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
        width: 360
        paddingH: Theme.spacingXl
        paddingV: Theme.spacingSm
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
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
            top: parent.top
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
