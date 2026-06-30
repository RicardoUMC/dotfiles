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

    // Bar silhouette — single continuous ShapePath curved frame (z:0, sole background)
    Shape {
        z: 0
        anchors.fill: parent
        visible: Theme.barStyle === "silhouette"

        ShapePath {
            id: barSilhouette

            // Runtime geometry computed from parent scope — used via fully qualified refs
            // inside nested Path objects to avoid ReferenceError.
            property real sGapL: centerTab.x
            property real sGapR: centerTab.x + centerTab.width
            property real sDepth: root.height * Theme.barCurveDepthRatio
            property real sInset: barSilhouette.strokeWidth / 2
            property real sGapW: 30

            strokeWidth: Theme.debugBarSilhouette ? 2 : 1
            strokeColor: Theme.debugBarSilhouette
                ? Theme.debugBorderColor
                : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.islandBorderOpacity)
            fillColor: Theme.debugBarSilhouette
                ? Qt.rgba(1.0, 0.2, 0.2, 0.3)
                : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.tabBgOpacity)
            joinStyle: Qt.RoundJoin

            // Start at top edge, just past top-left rounded corner
            startX: barSilhouette.sInset + Theme.tabRadius
            startY: barSilhouette.sInset

            // Top edge (left to right)
            PathLine {
                x: root.width - barSilhouette.sInset - Theme.tabRadius
                y: barSilhouette.sInset
            }

            // Top-right corner arc
            PathArc {
                x: root.width - barSilhouette.sInset
                y: barSilhouette.sInset + Theme.tabRadius
                radiusX: Theme.tabRadius
                radiusY: Theme.tabRadius
            }

            // Right edge (top to bottom)
            PathLine {
                x: root.width - barSilhouette.sInset
                y: root.height - barSilhouette.sInset
            }

            // Bottom edge (right to left, with concave transitions at section gaps)
            // Right section flat bottom → gapR
            PathLine {
                x: barSilhouette.sGapR + barSilhouette.sGapW / 2
                y: root.height - barSilhouette.sInset
            }

            // Concave transition at gapR (between right and center sections)
            PathCubic {
                control1X: barSilhouette.sGapR + barSilhouette.sGapW * 0.275
                control1Y: root.height - barSilhouette.sInset - barSilhouette.sDepth
                control2X: barSilhouette.sGapR - barSilhouette.sGapW * 0.275
                control2Y: root.height - barSilhouette.sInset - barSilhouette.sDepth
                x: barSilhouette.sGapR - barSilhouette.sGapW / 2
                y: root.height - barSilhouette.sInset
            }

            // Center section flat bottom → gapL
            PathLine {
                x: barSilhouette.sGapL + barSilhouette.sGapW / 2
                y: root.height - barSilhouette.sInset
            }

            // Concave transition at gapL (between center and left sections)
            PathCubic {
                control1X: barSilhouette.sGapL + barSilhouette.sGapW * 0.275
                control1Y: root.height - barSilhouette.sInset - barSilhouette.sDepth
                control2X: barSilhouette.sGapL - barSilhouette.sGapW * 0.275
                control2Y: root.height - barSilhouette.sInset - barSilhouette.sDepth
                x: barSilhouette.sGapL - barSilhouette.sGapW / 2
                y: root.height - barSilhouette.sInset
            }

            // Left section flat bottom → bottom-left
            PathLine {
                x: barSilhouette.sInset
                y: root.height - barSilhouette.sInset
            }

            // Left edge (bottom to top)
            PathLine {
                x: barSilhouette.sInset
                y: barSilhouette.sInset + Theme.tabRadius
            }

            // Top-left corner arc
            PathArc {
                x: barSilhouette.sInset + Theme.tabRadius
                y: barSilhouette.sInset
                radiusX: Theme.tabRadius
                radiusY: Theme.tabRadius
            }
        }
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
