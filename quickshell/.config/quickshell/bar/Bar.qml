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
    readonly property string barPosition: barConfig && barConfig.bar ? barConfig.bar.position : "top"
    readonly property bool vertical: barPosition === "left" || barPosition === "right"
    readonly property var endpointOrder: barConfig && barConfig.bar && barConfig.bar.order
        ? barConfig.bar.order : ["workspaces", "services"]
    readonly property var contentPolicy: barConfig && barConfig.bar && barConfig.bar.content
        ? barConfig.bar.content : ({ workspaceMode: "numbers", appMode: "active-icon", clockMode: "auto" })
    readonly property string startEndpoint: endpointOrder[0] === "services" ? "services" : "workspaces"
    readonly property string endEndpoint: startEndpoint === "services" ? "workspaces" : "services"
    readonly property bool servicesAtStart: startEndpoint === "services"
    readonly property string workspaceMode: contentPolicy.workspaceMode || "numbers"
    readonly property string appMode: contentPolicy.appMode || "active-icon"
    readonly property string clockMode: contentPolicy.clockMode || "auto"
    readonly property string dividerMode: barConfig && barConfig.bar && barConfig.bar.divider
        ? barConfig.bar.divider : "arc"
    WlrLayershell.layer: WlrLayer.Top
    // The in-surface right control center uses non-modal focus: OnDemand lets
    // it receive keyboard input when requested, while Escape closes it without
    // taking exclusive focus from the rest of the session.
    WlrLayershell.keyboardFocus: rightControlCenter.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        top: barPosition === "top" || vertical
        bottom: barPosition === "bottom" || vertical
        left: barPosition === "left" || !vertical
        right: barPosition === "right" || !vertical
    }
    readonly property real sideTabHeight: Math.max(leftTab.implicitHeight, rightTab.implicitHeight)
    readonly property real sideTabWidth: Math.max(leftTab.implicitWidth, rightTab.implicitWidth)
    readonly property real stableSurfaceContentHeight: Math.max(sideTabHeight, Theme.centerExpandedHeight)
    // A left bar's cross-axis width follows the rotated dashboard: the top
    // dashboard height becomes the left bar's expanded width. Keep the
    // collapsed surface narrow instead of reserving the horizontal dashboard
    // width on every left-positioned monitor.
    readonly property real stableSurfaceContentWidth: Math.max(
        sideTabWidth,
        vertical ? Theme.centerExpandedHeight : Theme.centerExpandedWidth)
    readonly property real centerCollapsedHeight: centerHeader.implicitHeight + centerTab.paddingV * 2
    readonly property real reservedBarContentHeight: Math.max(
        leftSection.reservedHeight,
        centerSection.reservedHeight,
        rightSection.reservedHeight)
    // Reserve only the collapsed interactive bar height. Keep the underlying
    // PanelWindow surface sized for the largest center state so opening the
    // dashboard does not resize the layer-shell surface or shift tiled windows.
    exclusiveZone: Math.ceil(vertical ? reservedBarContentWidth : reservedBarContentHeight)
    readonly property real reservedBarContentWidth: Math.max(
        leftSection.reservedWidth,
        centerSection.reservedWidth,
        rightSection.reservedWidth)

    // Full-output height: the right control center now renders inside this
    // surface, so the window must span the whole output for its below-bar
    // body and outside-click backdrop. While `screen` is still null at
    // startup, fall back to the old content-height formula. Anchors stay
    // top/left/right ONLY (never bottom) so the exclusive zone remains
    // unambiguously top-edge.
    implicitWidth: vertical
        ? stableSurfaceContentWidth + Theme.barWrapDepth
        : (screen !== null ? screen.width : stableSurfaceContentWidth)
    implicitHeight: vertical
        ? (screen !== null ? screen.height : stableSurfaceContentHeight)
        : (screen !== null ? screen.height : (stableSurfaceContentHeight + (Theme.barStyle === "silhouette" ? Theme.barWrapDepth : 0)))
    margins { top: 0; bottom: 0; left: 0; right: 0 }
    color: "transparent"
    BackgroundEffect.blurRegion: Theme.nativeBlur && Theme.surfaceMode === "glass"
        ? barGlassRegion
        : null
    // Island blur follows this Bar instance: Quickshell's screen Variants
    // create one Bar for each selected connected screen. The global switch
    // remains the only island-specific opt-out; visible and input masks stay
    // independent from this bounded native Region composition.
    readonly property bool islandNativeBlurEnabled: Theme.surfaceMode === "glass"
        && Theme.nativeBlur
        && Theme.islandNativeBlur
    GlassEffect {
        id: barGlassRegion
        // Island blur geometry is visual-only and remains separate from the
        // authoritative Canvas/MultiEffect and hit masks.
        Region {
            IslandBlurRegion {
                targetItem: leftSection
                nativeBlurEnabled: root.islandNativeBlurEnabled
                intersection: root.islandNativeBlurEnabled ? Intersection.Combine : Intersection.Subtract
            }
            IslandBlurRegion {
                targetItem: centerSection
                nativeBlurEnabled: root.islandNativeBlurEnabled
                intersection: root.islandNativeBlurEnabled ? Intersection.Combine : Intersection.Subtract
            }
            IslandBlurRegion {
                targetItem: rightSection
                nativeBlurEnabled: root.islandNativeBlurEnabled
                intersection: root.islandNativeBlurEnabled ? Intersection.Combine : Intersection.Subtract
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
    // Normalized configuration, resolved once by Theme for this screen.
    // Visibility is consumed by shell.qml before this instance is created;
    // placement, style, and dashboard attachment remain future work.
    property var barConfig: ({})
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
        mprisPopup.anchorY = root.mprisChipGlobalY
        mprisPopup.open()
    }
    function setMprisAnchor() {
        mprisPopup.anchorX = root.mprisChipGlobalX
        mprisPopup.anchorY = root.mprisChipGlobalY
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
    readonly property var activeServicesEndpoint: root.servicesAtStart
        ? startEndpointLoader.item : endEndpointLoader.item
    readonly property var activePowerButton: root.activeServicesEndpoint
        ? root.activeServicesEndpoint.powerButton : null
    readonly property real powerBtnGlobalX: root.activePowerButton
        ? root.activePowerButton.mapToItem(null, 0, 0).x : 0
    readonly property real powerBtnGlobalY: root.activePowerButton
        ? root.activePowerButton.mapToItem(null, 0, 0).y : 0
    function pointInInteractiveBar(px, py) {
        if (barPosition === "top") return py < reservedBarContentHeight
        if (barPosition === "bottom") return py >= height - reservedBarContentHeight
        if (barPosition === "left") return px < reservedBarContentWidth
        return px >= width - reservedBarContentWidth
    }
    function pointInPower(px, py) {
        const power = root.activePowerButton
        if (!power) return false
        const origin = power.mapToItem(null, 0, 0)
        return px >= origin.x && px <= origin.x + power.width
            && py >= origin.y && py <= origin.y + power.height
    }
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
    readonly property real mprisChipGlobalY: {
        const origin = mprisChip.mapToItem(null, 0, 0)
        return Number.isFinite(origin.y) ? origin.y + mprisChip.height / 2 : centerTab.y + centerTab.height / 2
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

    Component {
        id: workspaceEndpointComponent
        Workspaces {
            vertical: root.vertical
            workspaceMode: root.workspaceMode
            appMode: root.appMode
            monitor: root.hyprlandMonitor
            workspaceMonitorTick: root.workspaceMonitorTick
        }
    }

    Component {
        id: servicesEndpointComponent
        ServiceEndpoint {
            vertical: root.vertical
            barPosition: root.barPosition
            dividerMode: root.dividerMode
            notificationsState: root.notificationsState
            onSectionRequested: function(section) {
                root.rightControlCenterSectionRequested(section)
            }
        }
    }

    BarSection {
        id: leftSection
        z: 0
        targetItem: leftTab
        sectionId: "left"
        collapsedHeight: root.sideTabHeight
        vertical: root.vertical
        edge: root.barPosition
        hasWrap: true
        leftCornerEnabled: root.barPosition === "left"
        rightCornerEnabled: true
        bottomLeftRounded: root.barPosition === "left"
        bottomRightRounded: true
    }

    // Optional Stage-2 native feasibility surface. It is created only for
    // the explicitly selected left island and exact owning screen; production
    // masks, hit regions, and the bar's input union remain untouched.
    Loader {
        active: Theme.islandNativePrototypeTarget === "left"
            && Theme.islandNativePrototypeScreen.length > 0
            && root.screenName === Theme.islandNativePrototypeScreen
        sourceComponent: Component {
            IslandNativePrototype {
                screenTarget: root.screen
                sectionX: leftSection.x
                sectionY: leftSection.y
                sectionWidth: leftSection.width
                sectionHeight: leftSection.targetItem.height
                cornerRadius: leftSection._cornerSize
                wrapDepth: leftSection._wrapDepth
            }
        }
    }

    BarSection {
        id: centerSection
        z: 0
        targetItem: centerTab
        sectionId: "center"
        collapsedHeight: root.centerCollapsedHeight
        vertical: root.vertical
        edge: root.barPosition
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
        vertical: root.vertical
        edge: root.barPosition
        hasWrap: true
        leftCornerEnabled: true
        rightCornerEnabled: root.barPosition === "left"
        bottomLeftRounded: true
        bottomRightRounded: root.barPosition === "left"
    }

    // Left tab — Workspaces
    BarTab {
        id: leftTab
        z: 1
        compact: true
        vertical: root.vertical
        width: root.vertical ? root.sideTabWidth : implicitWidth
        height: root.vertical ? implicitHeight : root.sideTabHeight
        x: root.vertical && root.barPosition === "right" ? parent.width - width : 0
        y: root.vertical
            ? 0
            : (root.barPosition === "bottom" ? parent.height - height : 0)

        Loader {
            id: startEndpointLoader
            sourceComponent: root.startEndpoint === "workspaces"
                ? workspaceEndpointComponent : servicesEndpointComponent
        }
    }

    // Center tab — grows in place into the dashboard body.
    BarTab {
        id: centerTab
        z: 2
        readonly property bool expanded: centerPanel.isOpen

        vertical: root.vertical
        width: root.vertical ? (expanded ? Theme.centerExpandedHeight : centerCollapsedHeight) : (expanded ? Theme.centerExpandedWidth : Theme.centerCollapsedWidth)
        height: root.vertical ? (expanded ? Theme.centerExpandedWidth : Theme.centerCollapsedWidth) : implicitHeight
        paddingH: Theme.spacingXl
        paddingV: Theme.spacingSm
        x: root.vertical ? (root.barPosition === "right" ? parent.width - width : 0) : (parent.width - width) / 2
        y: root.vertical ? (parent.height - height) / 2 : (root.barPosition === "bottom" ? parent.height - height : 0)

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

                ClockChip {
                    expanded: false
                    vertical: root.vertical
                    orientationMode: root.clockMode
                }

                MprisIndicator {
                    id: mprisChip
                    compact: root.vertical
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
        vertical: root.vertical
        width: root.vertical ? root.sideTabWidth : implicitWidth
        height: root.vertical ? implicitHeight : root.sideTabHeight
        x: root.vertical && root.barPosition === "right" ? parent.width - width : (root.vertical ? 0 : parent.width - width)
        y: root.vertical
            ? parent.height - height
            : (root.barPosition === "bottom" ? parent.height - height : 0)

        Loader {
            id: endEndpointLoader
            sourceComponent: root.endEndpoint === "workspaces"
                ? workspaceEndpointComponent : servicesEndpointComponent
        }
    }

    MetricsDropdown {
        id: metricsDropdown
        // Pin to this bar's screen; an unpinned layer-shell surface lets
        // the compositor choose the output.
        screenTarget: root.screen
        systemStatsState: root.systemStatsState
        barPosition: root.barPosition
        vertical: root.vertical
        barWidth: root.reservedBarContentWidth
        onOpened: root.metricsOpened()
        onClosed: root.metricsClosed()
    }

    MprisPopup {
        id: mprisPopup
        // Pin to this bar's screen; an unpinned layer-shell surface lets
        // the compositor choose the output.
        screenTarget: root.screen
        vertical: root.vertical
        barPosition: root.barPosition
        barWidth: root.reservedBarContentWidth
        anchorY: root.mprisChipGlobalY
        onClosed: root.mprisClosed()
    }

    CenterPanel {
        id: centerPanel
        // Pin to this bar's screen; an unpinned layer-shell surface lets
        // the compositor choose the output.
        screenTarget: root.screen
        centerX: centerSection.centerX
        centerY: centerSection.centerY
        centerWidth: centerSection.centerWidth
        centerHeight: centerSection.centerHeight
        vertical: root.vertical
        barPosition: root.barPosition
        onOpened: root.centerPanelOpened()
        onClosed: root.centerPanelClosed()
    }

    RightControlCenter {
        id: rightControlCenter
        notificationsState: root.notificationsState
        systemStatsState: root.systemStatsState
        onOpened: root.rightControlCenterOpened()
        onClosed: root.rightControlCenterClosed()
        barPosition: root.barPosition
        vertical: root.vertical
        barWidth: root.reservedBarContentWidth
    }
}
