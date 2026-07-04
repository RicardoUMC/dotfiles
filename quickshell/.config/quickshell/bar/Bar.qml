import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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

    // Segment fill: normal base01 or high-contrast debug red
    readonly property color segmentFill: Theme.debugBarSilhouette
        ? Qt.rgba(1.0, 0.2, 0.2, 0.65)
        : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.tabBgOpacity)

    // --- Island silhouette: single fill surface + composite mask ---
    // A full-width Rectangle provides pigment; MultiEffect clips it to three
    // visible regions (left, center, right) matching BarTab bounds via an
    // invisible white-rectangle mask. Gaps between segments stay transparent
    // because the mask has no geometry there.

    // Fill surface — pigment only, never rendered directly (MultiEffect captures it).
    Rectangle {
        id: silhouetteFill
        anchors.fill: parent
        visible: false
        layer.enabled: true
        color: root.segmentFill
    }

    // Mask geometry — invisible render target for MultiEffect.
    // Keep the three bar islands separated. The sketch-like detail is local:
    // square top edges with rounded lower/internal corners at the section gaps.
    Item {
        id: silhouetteMask
        visible: false
        layer.enabled: true
        anchors.fill: parent

        // Tuning params (visual-only; adjust via hot-reload)
        readonly property real _cornerRadius: Math.min(Theme.tabRadius * 1.8, parent.height)

        Canvas {
            id: frameMaskCanvas
            anchors.fill: parent
            antialiasing: true

            property real leftX: leftTab.x
            property real leftW: leftTab.width
            property real centerX: centerTab.x
            property real centerW: centerTab.width
            property real rightX: rightTab.x
            property real rightW: rightTab.width
            property real cornerRadius: silhouetteMask._cornerRadius

            onLeftXChanged: requestPaint()
            onLeftWChanged: requestPaint()
            onCenterXChanged: requestPaint()
            onCenterWChanged: requestPaint()
            onRightXChanged: requestPaint()
            onRightWChanged: requestPaint()
            onCornerRadiusChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function roundedRect(ctx, x, y, w, h, r, tl, tr, br, bl) {
                const radius = Math.max(0, Math.min(r, w / 2, h / 2));
                ctx.beginPath();
                ctx.moveTo(x + (tl ? radius : 0), y);
                ctx.lineTo(x + w - (tr ? radius : 0), y);
                if (tr) ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
                else ctx.lineTo(x + w, y);
                ctx.lineTo(x + w, y + h - (br ? radius : 0));
                if (br) ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
                else ctx.lineTo(x + w, y + h);
                ctx.lineTo(x + (bl ? radius : 0), y + h);
                if (bl) ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
                else ctx.lineTo(x, y + h);
                ctx.lineTo(x, y + (tl ? radius : 0));
                if (tl) ctx.quadraticCurveTo(x, y, x + radius, y);
                else ctx.lineTo(x, y);
                ctx.closePath();
                ctx.fill();
            }

            onPaint: {
                const ctx = getContext("2d");
                const r = frameMaskCanvas.cornerRadius;

                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "white";

                // Left: square at screen edge and top edge; rounded only where it
                // drops away into the transparent gap.
                roundedRect(ctx, frameMaskCanvas.leftX, 0, frameMaskCanvas.leftW, height, r, false, false, true, false);

                // Center: square top edge, rounded lower corners only.
                roundedRect(ctx, frameMaskCanvas.centerX, 0, frameMaskCanvas.centerW, height, r, false, false, true, true);

                // Right: mirrored local detail at the gap-facing lower corner;
                // square at screen edge and top edge.
                roundedRect(ctx, frameMaskCanvas.rightX, 0, frameMaskCanvas.rightW, height, r, false, false, false, true);
            }
        }
    }

    // Composite effect — clips fill surface to visible regions.
    MultiEffect {
        id: silhouetteEffect
        source: silhouetteFill
        maskEnabled: true
        maskSource: silhouetteMask
        anchors.fill: parent
        visible: Theme.barStyle === "silhouette"
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
