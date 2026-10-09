import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Wayland._BackgroundEffect
import "../services"
import "../theme"

PanelWindow {
    id: root

    // Interactive panel surface: explicitly Top, never the Quickshell default.
    // Toasts and the OSD own WlrLayer.Overlay so system feedback always draws
    // above every panel; relying on the default here would let a future
    // Quickshell default change silently reorder the bar against the panels
    // that now declare Top by hand. See specs/overlay-manager.md.
    WlrLayershell.layer: WlrLayer.Top
    // The in-surface right control center needs deterministic keyboard focus
    // for Escape while open. OnDemand lets the compositor retain another
    // surface's focus when this Bar is already mapped; Exclusive transfers
    // focus for the open interval, while None keeps the bar inert when closed.
    WlrLayershell.keyboardFocus: rightControlCenter.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

    // Full-output height: the right control center now renders inside this
    // surface, so the window must span the whole output for its below-bar
    // body and outside-click backdrop. While `screen` is still null at
    // startup, fall back to the old content-height formula. Anchors stay
    // top/left/right ONLY (never bottom) so the exclusive zone remains
    // unambiguously top-edge.
    implicitHeight: screen !== null ? screen.height : (stableSurfaceContentHeight + (Theme.barStyle === "silhouette" ? Theme.barWrapDepth : 0))
    margins { top: 0; left: 0; right: 0 }
    color: "transparent"
    BackgroundEffect.blurRegion: Theme.nativeBlur && Theme.surfaceMode === "glass"
        ? barGlassRegion
        : null
    GlassEffect {
        id: barGlassRegion
        // Island blur geometry is visual-only and remains separate from the
        // authoritative Canvas/MultiEffect and hit masks.
        Region {
            IslandBlurRegion {
                targetItem: leftSection
                intersection: Theme.islandNativeBlur ? Intersection.Combine : Intersection.Subtract
            }
            IslandBlurRegion {
                targetItem: centerSection
                intersection: Theme.islandNativeBlur ? Intersection.Combine : Intersection.Subtract
            }
            IslandBlurRegion {
                targetItem: rightSection
                intersection: Theme.islandNativeBlur ? Intersection.Combine : Intersection.Subtract
            }
        }

        // The panel body remains a native rounded region; do not replace it
        // with scanline geometry. Keep it out of the fullscreen input mask
        // below; its zero height while closed collapses this region.
        Region {
            item: rightControlCenter.panelBodyItem
            topLeftRadius: Theme.dashboardBodyRadius
            topRightRadius: Theme.dashboardBodyRadius
            bottomLeftRadius: Theme.dashboardBodyRadius
            bottomRightRadius: Theme.dashboardBodyRadius
        }
    }
    mask: Region {
        regions: [
            Region { item: leftSection.hit },
            Region { item: centerSection.hit },
            Region { item: rightSection.hit },
            // Fourth region: the right-control-center backdrop. Region{item}
            // reacts to the item's geometry only, so the backdrop reports 0x0
            // while closed and contributes an empty rect; while open it fills
            // the surface and takes outside clicks.
            Region { item: rightControlCenter.backdropItem }
        ]
    }

    property var notificationsState: null
    // Injected from shell.qml (single SystemStats engine instance). Null until wired.
    property var systemStatsState: null
    // Name of the screen this instance is bound to, sourced from
    // modelData.name by the shell.qml Variants delegate. Overlay routing
    // uses it as the screen identity; signals from this bar are handled
    // per instance so the coordinator knows which screen emitted them.
    property string screenName: ""
    // Injected from shell.qml: the Hyprland monitor this bar's screen maps to,
    // or null during startup / hot-plug until the monitor appears. Resolved
    // once centrally so no per-screen component probes the compositor itself.
    property var hyprlandMonitor: null
    // Injected from shell.qml: bumped on every workspace-to-monitor move, the
    // event that mutates HyprlandWorkspace.monitor without notifying the global
    // workspace model. Forwarded to the workspace island so its monitor filter
    // re-evaluates instead of going stale.
    property int workspaceMonitorTick: 0

    // IPC signals
    signal mprisClosed()
    signal metricsOpened()
    signal metricsClosed()
    signal centerPanelToggleRequested()
    signal centerPanelOpened()
    signal centerPanelClosed()
    signal rightControlCenterToggleRequested()
    signal rightControlCenterSectionRequested(string section)
    signal rightControlCenterOpened()
    signal rightControlCenterClosed()

    // IPC functions
    function closeMpris()     { mprisPopup.close() }
    function openMetrics()    { metricsDropdown.open() }

    function wifiSignalGlyph(signal) {
        const value = Math.max(0, Number(signal || 0))
        if (value < 20)
            return "󰤯"
        if (value < 40)
            return "󰤟"
        if (value < 60)
            return "󰤢"
        if (value < 80)
            return "󰤥"
        return "󰤨"
    }
    function closeMetrics()   { metricsDropdown.close() }
    function openMpris() {
        mprisPopup.anchorX = root.mprisChipGlobalX
        mprisPopup.open()
    }
    function setMprisAnchor() {
        mprisPopup.anchorX = root.mprisChipGlobalX
    }
    function openCenterPanel()  { centerPanel.open() }
    function closeCenterPanel() { centerPanel.close() }
    function openRightControlCenter()  { rightControlCenter.open() }
    function openRightControlCenterSection(section) { rightControlCenter.openSection(section) }
    function closeRightControlCenter() { rightControlCenter.close() }

    // IPC readonly properties
    // Power is a section of the right control center, not a standalone overlay,
    // so its visibility derives from the RCC's open state and active section.
    readonly property bool powerMenuVisible: rightControlCenter.isOpen && rightControlCenter.activeSection === "power"
    readonly property real powerBtnGlobalX:  rightTab.x + rightTab.width - powerMenu.implicitWidth - Theme.tabPaddingH
    // Horizontal center of the media chip, in this bar's window coordinates.
    // The collapsed header is [fill, ClockChip, MprisIndicator, fill] with two
    // equal Layout.fillWidth items, so clock and chip are centered as a PAIR:
    // the chip's center sits (clockWidth + headerSpacing) / 2 right of the
    // center tab's midpoint. That offset is independent of the chip's own
    // width — widening the title moves both edges equally, so the midpoint
    // stays put. Measured here: (88.5 + 8) / 2 ≈ 48 px, observed 49 px after
    // RowLayout's integer rounding. Using the tab midpoint instead left only
    // the chip's left third clickable and let clicks over the clock's right
    // side open the popup. mapToItem() is a plain function call, so the
    // binding also reads mprisChip.x to observe the chip actually moving.
    // Deriving the value from the chip's own geometry, rather than from
    // hand-computed width offsets, keeps it correct when the header composition
    // changes. mapToItem(null, ...) yields window-relative coordinates, and this
    // bar surface spans the full screen width at x = 0, so bar-local x and the
    // launcher's outside-click x agree on the same monitor.
    readonly property real mprisChipGlobalX: {
        // mprisChip.x is read for two reasons: it is a monotonicity sanity
        // check (window x cannot sit left of the chip's own x, since every
        // ancestor offset here is non-negative), and it registers a binding
        // dependency. mapToItem() is a function call, so the engine cannot see
        // that the chip moved when the fillers re-center the clock/chip pair;
        // without this read the value would go stale on a clock-width change.
        const localX = mprisChip.x
        const origin = mprisChip.mapToItem(null, 0, 0)
        const center = origin.x + mprisChip.width / 2
        // Degenerate states: the chip is `visible: active` and animates its
        // width, so an inactive or not-yet-mapped chip has no meaningful
        // geometry. Those must never reach MprisPopup.anchorX (a stale zero
        // would clamp the popup to the far left of the screen), so fall back to
        // the center-tab midpoint. Consumers still gate on mprisChipActive.
        if (!Number.isFinite(center) || mprisChip.width <= 0 || center < localX)
            return centerTab.x + centerTab.width / 2
        return center
    }
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

        Workspaces {
            monitor: root.hyprlandMonitor
            workspaceMonitorTick: root.workspaceMonitorTick
        }
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
                color: Theme.surface(Colors.base00)
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
                    systemStatsState: root.systemStatsState
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

    // Right tab — compact control-center entries + PowerMenu button
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

        RightIslandIconButton {
            id: wifiButton
            icon: WifiService.wifiEnabled ? root.wifiSignalGlyph(WifiService.activeSignal) : "󰤭"
            label: "Wi-Fi"
            disabled: !WifiService.wifiEnabled
            active: WifiService.wifiEnabled && WifiService.activeSsid.length > 0
            onClicked: root.rightControlCenterSectionRequested("wifi")
        }

        RightIslandIconButton {
            id: bluetoothButton
            icon: BluetoothService.bluetoothEnabled ? "󰂯" : "󰂲"
            label: "Bluetooth"
            disabled: !BluetoothService.bluetoothEnabled
            active: BluetoothService.bluetoothEnabled && (BluetoothService.connectedDevices || []).length > 0
            onClicked: root.rightControlCenterSectionRequested("bluetooth")
        }

        RightIslandIconButton {
            id: audioButton
            icon: AudioService.outputMuted ? "󰝟" : "󰕾"
            label: "Audio"
            active: !AudioService.outputMuted
            warning: AudioService.outputMuted
            onClicked: root.rightControlCenterSectionRequested("audio")
        }

        RightIslandIconButton {
            id: notificationButton
            icon: root.notificationsState && root.notificationsState.doNotDisturb ? "󰂛" : "󰂚"
            label: "Notifications"
            active: root.notificationsState && root.notificationsState.recentModel && root.notificationsState.recentModel.count > 0
            warning: root.notificationsState && (root.notificationsState.doNotDisturb || root.notificationsState.soundMuted)
            onClicked: root.rightControlCenterSectionRequested("notifications")
        }

        // Semantic divider between the service chips and the destructive
        // session action. Purely decorative: it takes no input and changes no
        // routing; islandSemanticGap widens the whitespace around it.
        Rectangle {
            Layout.preferredWidth: Theme.islandSeparatorWidth > 0
                                      ? Theme.islandSeparatorWidth + Theme.islandSemanticGap * 2
                                      : 0
            Layout.preferredHeight: Theme.barChipHeight - Theme.spacingSm
            Layout.alignment: Qt.AlignVCenter
            radius: Math.min(1, Theme.islandSeparatorWidth / 2)
            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
            visible: Theme.islandSeparatorWidth > 0
        }

        PowerMenu {
            id: powerMenu
            // The pill emits intent upward; the coordinator routes it to the
            // power section of the right control center, which owns the menu
            // content inside this surface. No surface opens from the pill
            // itself, and no global timer is involved for sibling switches.
            onToggleRequested: root.rightControlCenterSectionRequested("power")
        }
    }

    MetricsDropdown {
        id: metricsDropdown
        // Pin to this bar's screen; an unpinned layer-shell surface lets
        // the compositor choose the output.
        screenTarget: root.screen
        systemStatsState: root.systemStatsState
        onOpened: root.metricsOpened()
        onClosed: root.metricsClosed()
    }

    MprisPopup {
        id: mprisPopup
        // Pin to this bar's screen; an unpinned layer-shell surface lets
        // the compositor choose the output.
        screenTarget: root.screen
        onClosed: root.mprisClosed()
    }

    CenterPanel {
        id: centerPanel
        // Pin to this bar's screen; an unpinned layer-shell surface lets
        // the compositor choose the output.
        screenTarget: root.screen
        centerX: centerSection.centerX
        centerWidth: centerSection.centerWidth
        centerHeight: centerSection.centerHeight
        onOpened: root.centerPanelOpened()
        onClosed: root.centerPanelClosed()
    }

    RightControlCenter {
        id: rightControlCenter
        notificationsState: root.notificationsState
        systemStatsState: root.systemStatsState
        onOpened: root.rightControlCenterOpened()
        onClosed: root.rightControlCenterClosed()
    }
}
