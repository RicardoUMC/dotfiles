import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    readonly property real sideTabHeight: Math.max(leftTab.implicitHeight, rightTab.implicitHeight)
    readonly property real stableSurfaceContentHeight: Math.max(sideTabHeight, Theme.centerExpandedHeight)
    readonly property real centerCollapsedHeight: centerHeader.implicitHeight + centerTab.paddingV * 2
    readonly property real reservedBarContentHeight: Math.max(
        leftSection.reservedHeight,
        centerSection.reservedHeight,
        rightSection.reservedHeight)
    // Reserve only the collapsed interactive bar height. Keep the underlying
    // PanelWindow surface sized for the largest center state so opening the
    // dashboard does not resize the layer-shell surface or shift tiled windows.
    exclusiveZone: Math.ceil(reservedBarContentHeight)

    implicitHeight: stableSurfaceContentHeight + (Theme.barStyle === "silhouette" ? Theme.barWrapDepth : 0)
    margins { top: 0; left: 0; right: 0 }
    color: "transparent"
    mask: Region {
        regions: [
            Region { item: leftSection.hit },
            Region { item: centerSection.hit },
            Region { item: rightSection.hit }
        ]
    }

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

    BarSection {
        id: leftSection
        z: 0
        targetItem: leftTab
        sectionId: "left"
        collapsedHeight: root.sideTabHeight
        hasWrap: true
        leftCornerEnabled: false
        rightCornerEnabled: true
        bottomLeftRounded: false
        bottomRightRounded: true
    }

    BarSection {
        id: centerSection
        z: 0
        targetItem: centerTab
        sectionId: "center"
        collapsedHeight: root.centerCollapsedHeight
        hasWrap: false
        leftCornerEnabled: true
        rightCornerEnabled: true
        bottomLeftRounded: true
        bottomRightRounded: true
    }

    BarSection {
        id: rightSection
        z: 0
        targetItem: rightTab
        sectionId: "right"
        collapsedHeight: root.sideTabHeight
        hasWrap: true
        leftCornerEnabled: true
        rightCornerEnabled: false
        bottomLeftRounded: true
        bottomRightRounded: false
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

        Behavior on height {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd

            RowLayout {
                id: centerHeader
                Layout.fillWidth: true
                visible: !centerTab.expanded
                spacing: Theme.spacingSm

                Item { Layout.fillWidth: true }

                ClockChip { expanded: false }

                MprisIndicator {
                    id: mprisChip
                    visible: active
                    onClicked: {
                        if (!centerTab.expanded) {
                            dashboard.selectMediaTab()
                            root.centerPanelToggleRequested()
                        }
                        // Expanded branch intentionally empty: this header is hidden
                        // while expanded, so no visible expanded media target exists.
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0,
                    Theme.centerExpandedHeight
                    - (centerTab.expanded ? 0 : (Theme.barChipHeight + Theme.spacingMd))
                    - centerTab.paddingV * 2)
                visible: centerTab.expanded
                radius: Theme.dashboardBodyRadius
                color: Qt.rgba(Colors.base00.r, Colors.base00.g, Colors.base00.b, Theme.dashboardBodyOpacity)
                border {
                    width: Theme.dashboardBodyBorderWidth
                    color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => mouse.accepted = true
                }

                CenterDashboard {
                    id: dashboard
                    anchors { fill: parent; margins: Theme.dashboardBodyPadding }
                    mediaPlayer: root.mediaPlayer
                    systemStatsState: statsEngine.dataState
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
        centerX: centerSection.centerX
        centerWidth: centerSection.centerWidth
        centerHeight: centerSection.centerHeight
        onOpened: root.centerPanelOpened()
        onClosed: root.centerPanelClosed()
    }
}
