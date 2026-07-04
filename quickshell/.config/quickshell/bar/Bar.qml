import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    readonly property real barContentHeight: Math.max(leftTab.implicitHeight, centerTab.implicitHeight, rightTab.implicitHeight)
    // Single source of truth for the silhouette curvature. Every notch, wrap,
    // and lower island radius uses this value so the shape tunes as one system.
    readonly property real silhouetteCornerSize: Math.min(Theme.tabRadius + 4, barContentHeight)

    // Reserve only the interactive/content height. The wrapped silhouette still
    // draws through implicitHeight, but it does not push tiled windows by its
    // full decorative depth.
    exclusiveZone: Math.ceil(barContentHeight)

    implicitHeight: barContentHeight + (Theme.barStyle === "silhouette" ? silhouetteCornerSize : 0)
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
    // Keep the three bar islands separated while borrowing Ambxst's default
    // notch composition: a rectangular body plus explicit mask-only corner
    // pieces on the gap-facing top edges.
    Item {
        id: silhouetteMask
        visible: false
        layer.enabled: true
        anchors.fill: parent

        readonly property real _cornerSize: root.silhouetteCornerSize

        NotchIslandMask {
            targetItem: leftTab
            cornerSize: silhouetteMask._cornerSize
            leftCornerEnabled: false
            rightCornerEnabled: true
            bottomLeftRounded: false
            bottomRightRounded: true
        }

        NotchIslandMask {
            targetItem: centerTab
            cornerSize: silhouetteMask._cornerSize
            leftCornerEnabled: true
            rightCornerEnabled: true
            bottomLeftRounded: true
            bottomRightRounded: true
        }

        NotchIslandMask {
            targetItem: rightTab
            cornerSize: silhouetteMask._cornerSize
            leftCornerEnabled: true
            rightCornerEnabled: false
            bottomLeftRounded: true
            bottomRightRounded: false
        }

        NotchCornerMask {
            x: leftTab.x
            y: leftTab.y + leftTab.height
            width: silhouetteMask._cornerSize
            height: width
            corner: "topLeft"
            color: "white"
            visible: width > 0
        }

        NotchCornerMask {
            x: rightTab.x + rightTab.width - width
            y: rightTab.y + rightTab.height
            width: silhouetteMask._cornerSize
            height: width
            corner: "topRight"
            color: "white"
            visible: width > 0
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

    component NotchIslandMask: Item {
        id: notchIslandMask

        required property Item targetItem
        property real cornerSize: 0
        property bool leftCornerEnabled: true
        property bool rightCornerEnabled: true
        property bool bottomLeftRounded: true
        property bool bottomRightRounded: true

        readonly property real resolvedCornerSize: Math.max(0, Math.min(cornerSize, height))

        x: targetItem.x - (leftCornerEnabled ? resolvedCornerSize : 0)
        y: targetItem.y
        width: targetItem.width
            + (leftCornerEnabled ? resolvedCornerSize : 0)
            + (rightCornerEnabled ? resolvedCornerSize : 0)
        height: targetItem.height

        NotchCornerMask {
            id: leftNotchCorner
            anchors.top: parent.top
            anchors.left: parent.left
            width: notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
            height: width
            corner: "topRight"
            color: "white"
            visible: notchIslandMask.leftCornerEnabled && width > 0
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: leftNotchCorner.right
            anchors.right: rightNotchCorner.left
            color: "white"
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: notchIslandMask.bottomLeftRounded ? notchIslandMask.resolvedCornerSize : 0
            bottomRightRadius: notchIslandMask.bottomRightRounded ? notchIslandMask.resolvedCornerSize : 0
        }

        NotchCornerMask {
            id: rightNotchCorner
            anchors.top: parent.top
            anchors.right: parent.right
            width: notchIslandMask.rightCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
            height: width
            corner: "topLeft"
            color: "white"
            visible: notchIslandMask.rightCornerEnabled && width > 0
        }
    }

    component NotchCornerMask: Item {
        id: notchCornerMask

        property string corner: "topLeft"
        property color color: "white"

        onCornerChanged: cornerCanvas.requestPaint()
        onColorChanged: cornerCanvas.requestPaint()
        onWidthChanged: cornerCanvas.requestPaint()
        onHeightChanged: cornerCanvas.requestPaint()

        Canvas {
            id: cornerCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                const r = Math.min(width, height);

                ctx.clearRect(0, 0, width, height);
                if (r <= 0) return;

                ctx.beginPath();
                switch (notchCornerMask.corner) {
                case "topRight":
                    ctx.arc(0, r, r, 3 * Math.PI / 2, 2 * Math.PI);
                    ctx.lineTo(r, 0);
                    break;
                case "bottomLeft":
                    ctx.arc(r, 0, r, Math.PI / 2, Math.PI);
                    ctx.lineTo(0, r);
                    break;
                case "bottomRight":
                    ctx.arc(0, 0, r, 0, Math.PI / 2);
                    ctx.lineTo(r, r);
                    break;
                case "topLeft":
                default:
                    ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2);
                    ctx.lineTo(0, 0);
                    break;
                }
                ctx.closePath();
                ctx.fillStyle = notchCornerMask.color;
                ctx.fill();
            }
        }
    }
}
