import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    readonly property real sideTabHeight: Math.max(leftTab.implicitHeight, rightTab.implicitHeight)
    readonly property real barContentHeight: Math.max(sideTabHeight, centerTab.implicitHeight)
    readonly property real reservedBarContentHeight: Math.max(sideTabHeight,
        centerHeader.implicitHeight + centerTab.paddingV * 2)
    // Single source of truth for the silhouette curvature. Every notch and lower
    // island radius uses this value so the shape tunes as one system.
    readonly property real silhouetteCornerSize: Math.min(Theme.barCurveRadius, barContentHeight)

    // Reserve only the collapsed interactive bar height. The expanded center
    // body still draws through implicitHeight, but it overlays tiled windows
    // instead of increasing Hyprland's reserved top margin.
    exclusiveZone: Math.ceil(reservedBarContentHeight)

    implicitHeight: barContentHeight + (Theme.barStyle === "silhouette" ? Theme.barWrapDepth : 0)
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
    readonly property bool centerPanelVisible: centerPanel.isOpen
    readonly property var mediaPlayer: {
        const players = Mpris.players.values
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

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
        readonly property real _wrapDepth: Theme.barWrapDepth

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
            height: silhouetteMask._wrapDepth
            radius: silhouetteMask._cornerSize
            corner: "topLeft"
            color: "white"
            visible: width > 0 && height > 0
        }

        NotchCornerMask {
            x: rightTab.x + rightTab.width - width
            y: rightTab.y + rightTab.height
            width: silhouetteMask._cornerSize
            height: silhouetteMask._wrapDepth
            radius: silhouetteMask._cornerSize
            corner: "topRight"
            color: "white"
            visible: width > 0 && height > 0
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
        height: root.sideTabHeight
        anchors {
            left: parent.left
            top: parent.top
            topMargin: 0
        }

        Workspaces {}
    }

    // Center tab — grows in place into the dashboard body.
    BarTab {
        id: centerTab
        z: 2
        readonly property bool expanded: centerPanel.isOpen

        width: expanded ? Theme.centerExpandedWidth : Theme.centerCollapsedWidth
        height: implicitHeight
        paddingH: Theme.spacingXl
        paddingV: Theme.spacingSm
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 0
        }

        Behavior on width {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd

            RowLayout {
                id: centerHeader
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Item { Layout.fillWidth: true }

                ClockChip { expanded: false }

                MprisIndicator {
                    id: mprisChip
                    visible: active
                    onClicked: {
                        if (!centerTab.expanded)
                            root.mprisToggleRequested()
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0,
                    Theme.centerExpandedHeight - Theme.barChipHeight - Theme.spacingMd - centerTab.paddingV * 2)
                visible: centerTab.expanded
                radius: Theme.radiusMd
                color: Qt.rgba(Colors.base00.r, Colors.base00.g, Colors.base00.b, 0.35)
                border {
                    width: 1
                    color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => mouse.accepted = true
                }

                ColumnLayout {
                    anchors { fill: parent; margins: Theme.spacingMd }
                    spacing: Theme.spacingMd

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Text {
                            text: "󰎆"
                            color: Colors.accent
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Media"
                            color: Colors.text
                            font { family: Colors.displayFont; pixelSize: Theme.fontSizeBodyLg }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.mediaPlayer?.trackTitle || "No media playing"
                            color: Colors.text
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                            elide: Text.ElideRight
                            horizontalAlignment: root.mediaPlayer ? Text.AlignLeft : Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.mediaPlayer !== null
                            text: root.mediaPlayer?.trackArtist ?? ""
                            color: Colors.textDim
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 3
                        radius: 2
                        visible: root.mediaPlayer !== null
                        color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)

                        Rectangle {
                            width: {
                                const len = root.mediaPlayer?.length ?? 0
                                const pos = root.mediaPlayer?.position ?? 0
                                return len > 0 ? parent.width * Math.min(1, Math.max(0, pos / len)) : 0
                            }
                            height: parent.height
                            radius: parent.radius
                            color: Colors.accent

                            Behavior on width {
                                NumberAnimation { duration: Theme.animSlow }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.mediaPlayer !== null
                        spacing: Theme.spacingXl

                        Text {
                            text: "󰒮"
                            color: Colors.textDim
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.mediaPlayer?.previous()
                            }
                        }

                        Text {
                            text: root.mediaPlayer?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                            color: Colors.accent
                            font { family: Colors.monoFont; pixelSize: 22 }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.mediaPlayer?.togglePlaying()
                            }
                        }

                        Text {
                            text: "󰒭"
                            color: Colors.textDim
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.mediaPlayer?.next()
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        parent: centerTab
        anchors.fill: parent
        z: -1
        onClicked: root.centerPanelToggleRequested()
    }

    // Right tab — MetricsButton + PowerMenu button
    BarTab {
        id: rightTab
        z: 1
        compact: true
        height: root.sideTabHeight
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
        centerX: centerTab.x
        centerWidth: centerTab.width
        centerHeight: centerTab.height
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
        property real radius: Math.min(width, height)

        onCornerChanged: cornerCanvas.requestPaint()
        onColorChanged: cornerCanvas.requestPaint()
        onRadiusChanged: cornerCanvas.requestPaint()
        onWidthChanged: cornerCanvas.requestPaint()
        onHeightChanged: cornerCanvas.requestPaint()

        Canvas {
            id: cornerCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                const r = Math.max(0, notchCornerMask.radius);

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
