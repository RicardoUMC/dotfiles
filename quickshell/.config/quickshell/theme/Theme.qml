pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    // Radius
    property int radiusSm:   6
    property int radiusMd:   10
    property int radiusLg:   12
    property int radiusPill: 999

    // Spacing
    property int spacingXs: 4
    property int spacingSm: 8
    property int spacingMd: 12
    property int spacingLg: 16
    property int spacingXl: 24

    // Opacity
    property real opacitySurface: 0.97
    property real opacityOverlay: 0.33
    property real opacityBorder:  0.30
    property real opacityDim:     0.15

    // Bar
    property int barHeight: 37
    property int barChipHeight: 30
    property int barCurveRadius: 14
    property int barWrapDepth: 14
    // Edge-reveal structural controls. Safe defaults keep the hot-zone narrow
    // and the hide delay long enough to move from the edge into the bar.
    property int revealStripThickness: 4
    property int revealHideDelay: 700
    property int centerCollapsedWidth: 360
    property int centerExpandedWidth: 520
    property int centerExpandedHeight: 260
    property int dashboardRailWidth: 44
    property int dashboardBodyRadius: 10
    property real dashboardBodyOpacity: 0.35
    // Global visual surface grammar. `glass` keeps the readable translucent
    // fill and opts into the native blur attached property on bounded regions.
    // Unsupported compositors may warn or no-op in Quickshell; the fill remains
    // the readable fallback. This option is intentionally inert in other modes.
    property string surfaceMode: "solid" // "solid" | "translucent" | "glass"
    property bool nativeBlur: true // `surface.nativeBlur`; only used by `glass`
    // Island-only switch for the bounded compositor-blur composition. The
    // right-control-center rounded region remains native-blurred independently.
    // Each active Bar instance follows the existing screen Variants model.
    property bool islandNativeBlur: false // `surface.islandNativeBlur`
    // Stage-1 synthetic GPU prototype target. `none` is the disabled default;
    // `left` is reserved for the future BarSection integration task.
    property string islandGpuPrototypeTarget: "none"
    // Stage-2 bounded native feasibility target. Both this and the exact
    // screen-name selector must opt in; empty selector means disabled.
    property string islandNativePrototypeTarget: "none"
    property string islandNativePrototypeScreen: ""
    property real surfaceOpacity: 1.0
    // Glass hierarchy: cards lift above the shell while nested slabs recede.
    // Solid mode still resolves every role to an opaque fill.
    property real surfaceCardOpacity: 0.24
    property real surfaceNestedOpacity: 0.12
    property real surfaceOverlayOpacity: 0.33

    // Button grammar: semantic fills may use the softer alpha-tinted island
    // treatment below; other action controls remain opaque and saturated.
    // Colors remain owned by Colors.qml; button tokens choose darkening/lift.
    property real buttonPrimaryTone: 0.32
    property real buttonSecondaryTone: 0.22
    property real buttonHoverLift: 0.08
    property real buttonPressedLift: 0.14
    function buttonFill(semanticColor, primary, state) {
        let tone = primary ? buttonPrimaryTone : buttonSecondaryTone
        if (state === "hover")
            tone += buttonHoverLift
        else if (state === "pressed")
            tone += buttonPressedLift
        tone = Math.min(1.0, Math.max(0.0, tone))
        return Qt.rgba(semanticColor.r * tone, semanticColor.g * tone,
                       semanticColor.b * tone, 1.0)
    }
    function surfaceColor(baseColor, roleOpacity) {
        const alpha = surfaceMode === "solid" ? 1.0
            : Math.min(1.0, Math.max(0.0, surfaceOpacity * roleOpacity))
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, alpha)
    }
    // Shell surfaces use the overlay role only in glass mode. Solid remains
    // opaque, and translucent keeps its existing global surface opacity.
    function surface(baseColor) {
        return surfaceColor(baseColor, surfaceMode === "glass" ? surfaceOverlayOpacity : 1.0)
    }
    function surfaceCard(baseColor) { return surfaceColor(baseColor, surfaceCardOpacity) }
    function surfaceNested(baseColor) { return surfaceColor(baseColor, surfaceNestedOpacity) }
    function rightPanelSurface(baseColor) { return surface(baseColor) }
    function rightPanelCardSurface(baseColor) { return surfaceCard(baseColor) }
    // Right control-center panel geometry (high-leverage structural tokens).
    property int rightPanelWidth: 360
    property int rightPanelPowerWidth: 160
    property int rightPanelMaxHeight: 600
    property int rightPanelTopMargin: 12
    property int rightPanelRightMargin: 12
    property int rightPanelPadding: 12
    property int rightPanelCardGap: 8
    property int dashboardBodyBorderWidth: 1
    property int dashboardBodyPadding: 12
    property int dashboardTabHeight: 40
    property int dashboardTabSpacing: 8
    property int dashboardCardHeight: 42
    property int dashboardCardGap: 4
    property int dashboardProgressHeight: 4
    property int dashboardProgressRadius: 2
    property int dashboardSparklineWidth: 80
    property int dashboardSparklineHeight: 32
    property int dashboardFooterHeight: 18

    // Panel chrome (control-center specialty cards; intentionally separate
    // from the dashboard progress tokens above)
    property int accentSeamWidth: 4              // hero accent seam width
    property int panelVolumeTrackHeight: 8       // Audio volume track and knob thickness
    property int panelSecondarySeamWidth: 2      // nested-panel seam; deliberately thinner than the accentSeamWidth hero seam - do not merge them

    // Which screens get a bar: "all", or an array of monitor names
    // (e.g. ["DP-1"]). Matched by ShellScreen.name only, never by index.
    property var barScreens: "all"

    property string barStyle: "silhouette"         // legacy: "silhouette" | "plain"
    property real barCurveDepthRatio: 0.2           // concave depth = height × ratio (legacy, use barNotchDepthRatio)
    // Future bar configuration is normalized independently from legacy bar.* keys.
    property var configurableBarSnapshot: ({
        bar: {
            position: "top",
            visibility: "always",
            style: "islands",
            revealPolicy: "external-edges",
            order: ["workspaces", "services"],
            content: { workspaceMode: "numbers", appMode: "active-icon", clockMode: "auto" },
            divider: "arc",
            motion: "calm"
        },
        dashboard: { attachment: "embedded" },
        monitors: ({})
    })
    property int configurableBarRevision: 0

    function _isConfigObject(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value)
    }

    function _validConfigEnum(value, allowed, fallback) {
        if (typeof value !== "string") return fallback
        return allowed.indexOf(value) >= 0 ? value : fallback
    }

    function _normalizedEndpointOrder(value) {
        const fallback = ["workspaces", "services"]
        if (!Array.isArray(value) || value.length !== 2) return fallback
        if (value.indexOf("workspaces") < 0 || value.indexOf("services") < 0) return fallback
        if (value[0] === value[1]) return fallback
        return [value[0], value[1]]
    }

    function _normalizedBarContent(value) {
        const source = _isConfigObject(value) ? value : ({})
        return {
            workspaceMode: _validConfigEnum(source.workspaceMode,
                ["numbers", "bullets", "active-only"], "numbers"),
            appMode: _validConfigEnum(source.appMode,
                ["hidden", "active-icon", "all-icons", "vertical-labels"], "active-icon"),
            clockMode: _validConfigEnum(source.clockMode,
                ["auto", "horizontal", "vertical", "hidden"], "auto")
        }
    }

    function _normalizedBarDefaults(value) {
        const source = _isConfigObject(value) ? value : ({})
        return {
            position: _validConfigEnum(source.position, ["top", "bottom", "left", "right"], "top"),
            visibility: _validConfigEnum(source.visibility, ["always", "edge-reveal", "disabled"], "always"),
            style: _validConfigEnum(source.style, ["islands", "continuous"], "islands"),
            revealPolicy: _validConfigEnum(source.revealPolicy, ["external-edges"], "external-edges"),
            order: _normalizedEndpointOrder(source.order),
            content: _normalizedBarContent(source.content),
            divider: _validConfigEnum(source.divider, ["arc", "hairline", "none"], "arc"),
            motion: _validConfigEnum(source.motion, ["reduced", "calm", "expressive"], "calm")
        }
    }

    function _normalizedBarOverride(value) {
        if (!_isConfigObject(value)) return ({})
        const normalized = ({})
        if (typeof value.position === "string" && ["top", "bottom", "left", "right"].indexOf(value.position) >= 0)
            normalized.position = value.position
        if (typeof value.visibility === "string" && ["always", "edge-reveal", "disabled"].indexOf(value.visibility) >= 0)
            normalized.visibility = value.visibility
        if (typeof value.style === "string" && ["islands", "continuous"].indexOf(value.style) >= 0)
            normalized.style = value.style
        if (typeof value.revealPolicy === "string" && value.revealPolicy === "external-edges")
            normalized.revealPolicy = value.revealPolicy
        if (value.order !== undefined)
            normalized.order = _normalizedEndpointOrder(value.order)
        if (value.content !== undefined)
            normalized.content = _normalizedBarContent(value.content)
        if (typeof value.divider === "string" && ["arc", "hairline", "none"].indexOf(value.divider) >= 0)
            normalized.divider = value.divider
        if (typeof value.motion === "string" && ["reduced", "calm", "expressive"].indexOf(value.motion) >= 0)
            normalized.motion = value.motion
        return normalized
    }

    function _normalizedBarConfig(cfg) {
        const bar = _isConfigObject(cfg.bar) ? cfg.bar : ({})
        const dashboard = _isConfigObject(cfg.dashboard) ? cfg.dashboard : ({})
        const monitors = _isConfigObject(cfg.monitors) ? cfg.monitors : ({})
        const normalizedMonitors = ({})
        Object.keys(monitors).forEach(function(name) {
            if (typeof name !== "string" || !_isConfigObject(monitors[name])) return
            const monitor = monitors[name]
            const normalized = ({})
            const barOverride = _normalizedBarOverride(monitor.bar)
            if (Object.keys(barOverride).length > 0) normalized.bar = barOverride
            if (_isConfigObject(monitor.dashboard)) {
                const attachment = monitor.dashboard.attachment
                if (typeof attachment === "string" && ["embedded", "detached"].indexOf(attachment) >= 0)
                    normalized.dashboard = { attachment: attachment }
            }
            if (Object.keys(normalized).length > 0) normalizedMonitors[name] = normalized
        })
        return {
            bar: _normalizedBarDefaults(bar.defaults),
            dashboard: {
                attachment: _validConfigEnum(dashboard.attachment, ["embedded", "detached"], "embedded")
            },
            monitors: normalizedMonitors
        }
    }

    // The sole resolver for future per-screen configuration. The revision read
    // is intentional: bindings calling this function re-evaluate on reload.
    function effectiveBarConfig(screenName) {
        const revision = configurableBarRevision
        const snapshot = configurableBarSnapshot
        const result = {
            bar: {
                position: snapshot.bar.position,
                visibility: snapshot.bar.visibility,
                style: snapshot.bar.style,
                revealPolicy: snapshot.bar.revealPolicy,
                order: snapshot.bar.order.slice(),
                content: {
                    workspaceMode: snapshot.bar.content.workspaceMode,
                    appMode: snapshot.bar.content.appMode,
                    clockMode: snapshot.bar.content.clockMode
                },
                divider: snapshot.bar.divider,
                motion: snapshot.bar.motion
            },
            dashboard: { attachment: snapshot.dashboard.attachment }
        }
        const monitor = snapshot.monitors && typeof screenName === "string"
            ? snapshot.monitors[screenName] : null
        if (monitor && monitor.bar) {
            if (monitor.bar.position !== undefined) result.bar.position = monitor.bar.position
            if (monitor.bar.visibility !== undefined) result.bar.visibility = monitor.bar.visibility
            if (monitor.bar.style !== undefined) result.bar.style = monitor.bar.style
            if (monitor.bar.revealPolicy !== undefined) result.bar.revealPolicy = monitor.bar.revealPolicy
            if (monitor.bar.order !== undefined) result.bar.order = monitor.bar.order.slice()
            if (monitor.bar.content !== undefined) {
                result.bar.content.workspaceMode = monitor.bar.content.workspaceMode
                result.bar.content.appMode = monitor.bar.content.appMode
                result.bar.content.clockMode = monitor.bar.content.clockMode
            }
            if (monitor.bar.divider !== undefined) result.bar.divider = monitor.bar.divider
            if (monitor.bar.motion !== undefined) result.bar.motion = monitor.bar.motion
        }
        if (monitor && monitor.dashboard && monitor.dashboard.attachment !== undefined)
            result.dashboard.attachment = monitor.dashboard.attachment
        return result
    }
    property real barNotchGapWidth: 30              // px gap at each section boundary
    property real barNotchDepthRatio: 0.2           // all segments share the same notch depth = height × ratio

    // Bar Tabs (Variant B)
    property int barRailHeight: 4      // thin top rail height
    property int tabPaddingH:   12     // horizontal content padding
    property int tabPaddingV:   5      // vertical content padding
    property int tabRadius:     10     // bottom corner radius
    property int tabMaxHeight:  60     // fully expanded center tab height
    property int  tabCollapsedHeight: 34  // collapsed tab height (content 26 + paddingV 5×2)
    property real tabBgOpacity:       1.0 // opaque bg; eliminates alpha-seam with rail

    // Islands (Variant A)
    property int  barHeightIslands:    52
    property int  islandPaddingH:      16
    property int  islandPaddingV:      6
    property int  islandGap:           8
    property real islandBlur:          12.0
    property real islandBgOpacity:     0.92
    property real islandBorderOpacity: 0.15

    // Right-island state grammar (fill/accent per chip - no generic outline)
    property int  islandChipRadius: 8                // right-island chip corner radius
    property real islandActiveFillOpacity: 0.18      // accent-tinted fill for active/warning chips
    property real islandStateLayerHoverOpacity: 0.10 // hover overlay on right-island chips
    property real islandStateLayerPressedOpacity: 0.16 // pressed overlay on right-island chips
    property int  islandSemanticGap: 4               // extra whitespace on each side of the service/power separator
    property int  islandSeparatorWidth: 1            // hairline dividing service chips from the power action; 0 hides it
    property real islandPowerTintOpacity: 0.10       // resting red tint of the destructive power button

    // Ornament (Variant A & B)
    property real ornamentOpacity: 0.07
    property real ornamentStroke:  1.5

    // Animation (ms)
    property int animFast:   180
    property int animNormal: 300
    property int animSlow:   500
    property bool animationsEnabled: true
    property var animationOverrides: ({})

    function animationEnabled(key) {
        if (!animationsEnabled)
            return false
        if (animationOverrides && animationOverrides[key] !== undefined)
            return animationOverrides[key] !== false
        return true
    }

    // Wallpaper-specific timing; global shell animation tokens stay unchanged.
    property int wallpaperOverlayDuration: 160
    property int wallpaperPreviewDelay: 120
    property string wallpaperTransition: "fade"
    property real wallpaperTransitionDuration: 1.0
    property int wallpaperTransitionFps: 30
    property int wallpaperTransitionStep: 90

    // Global motion multiplier applied by the Motion singleton on top of the
    // durations above (`anim.scale`). 1.0 preserves the current timing exactly;
    // it never rewrites animFast/animNormal/animSlow, so unmigrated call sites
    // keep answering to the plain duration tokens.
    property real animScale: 1.0

    // Font sizes
    property int fontSizeCaption: 12
    property int fontSizeLabel:   13
    property int fontSizeBody:    15
    property int fontSizeBodyLg:  17
    property int fontSizeIcon:    22

    // Debug / Visual Bounds (development scaffolding)
    // Set debugVisualBounds: false in config.json before final polish
    property bool  debugVisualBounds: false
    property color debugBorderColor:  "#ff3344"
    property int   debugBorderWidth:  1
    property bool  debugBarSilhouette: false         // high-contrast debug silhouette fill/stroke

    // Hot-reload
    property Timer debounce: Timer {
        interval: 100
        onTriggered: applyConfig()
    }

    property FileView configFile: FileView {
        path: Quickshell.shellDir + "/config.json"
        watchChanges: true
        onFileChanged: {
            reload()
            debounce.restart()
        }
    }

    function applyConfig() {
        try {
            const cfg = JSON.parse(configFile.text())
            if (!_isConfigObject(cfg)) throw new Error("config root must be an object")
            configurableBarSnapshot = _normalizedBarConfig(cfg)
            configurableBarRevision++
            if (cfg.radius?.sm   !== undefined) radiusSm   = cfg.radius.sm
            if (cfg.radius?.md   !== undefined) radiusMd   = cfg.radius.md
            if (cfg.radius?.lg   !== undefined) radiusLg   = cfg.radius.lg
            if (cfg.radius?.pill !== undefined) radiusPill = cfg.radius.pill
            if (cfg.spacing?.xs  !== undefined) spacingXs  = cfg.spacing.xs
            if (cfg.spacing?.sm  !== undefined) spacingSm  = cfg.spacing.sm
            if (cfg.spacing?.md  !== undefined) spacingMd  = cfg.spacing.md
            if (cfg.spacing?.lg  !== undefined) spacingLg  = cfg.spacing.lg
            if (cfg.spacing?.xl  !== undefined) spacingXl  = cfg.spacing.xl
            if (cfg.opacity?.surface !== undefined) opacitySurface = cfg.opacity.surface
            if (cfg.opacity?.overlay !== undefined) opacityOverlay = cfg.opacity.overlay
            if (cfg.opacity?.border  !== undefined) opacityBorder  = cfg.opacity.border
            if (cfg.opacity?.dim     !== undefined) opacityDim     = cfg.opacity.dim
            if (cfg.bar?.height             !== undefined) barHeight             = cfg.bar.height
            if (cfg.bar?.chipHeight         !== undefined) barChipHeight         = cfg.bar.chipHeight
            if (cfg.bar?.curveRadius        !== undefined) barCurveRadius        = cfg.bar.curveRadius
            if (cfg.bar?.wrapDepth          !== undefined) barWrapDepth          = cfg.bar.wrapDepth
            if (cfg.bar?.revealStripThickness !== undefined) {
                const stripThickness = Number(cfg.bar.revealStripThickness)
                if (Number.isFinite(stripThickness))
                    revealStripThickness = Math.min(32, Math.max(1, Math.round(stripThickness)))
            }
            if (cfg.bar?.revealHideDelay !== undefined) {
                const hideDelay = Number(cfg.bar.revealHideDelay)
                if (Number.isFinite(hideDelay))
                    revealHideDelay = Math.min(10000, Math.max(100, Math.round(hideDelay)))
            }
            if (cfg.bar?.centerCollapsedWidth !== undefined) centerCollapsedWidth = cfg.bar.centerCollapsedWidth
            if (cfg.bar?.centerExpandedWidth  !== undefined) centerExpandedWidth  = cfg.bar.centerExpandedWidth
            if (cfg.bar?.centerExpandedHeight !== undefined) centerExpandedHeight = cfg.bar.centerExpandedHeight
            if (cfg.bar && cfg.bar.screens !== undefined) barScreens = cfg.bar.screens
            if (cfg.bar && cfg.bar.style !== undefined) {
                barStyle = cfg.bar.style
            } else if (cfg.bar?.outerFrame !== undefined) {
                barStyle = cfg.bar.outerFrame ? "silhouette" : "plain"
            }
            if (cfg.bar?.curveDepthRatio    !== undefined) barCurveDepthRatio    = cfg.bar.curveDepthRatio
            if (cfg.bar?.notchGapWidth          !== undefined) barNotchGapWidth          = cfg.bar.notchGapWidth
            if (cfg.bar?.notchDepthRatio        !== undefined) barNotchDepthRatio        = cfg.bar.notchDepthRatio
            else if (cfg.bar?.curveDepthRatio    !== undefined) barNotchDepthRatio        = cfg.bar.curveDepthRatio
            if (cfg.bar?.heightIslands      !== undefined) barHeightIslands      = cfg.bar.heightIslands
            if (cfg.bar?.railHeight         !== undefined) barRailHeight         = cfg.bar.railHeight
            if (cfg.tab?.paddingH           !== undefined) tabPaddingH           = cfg.tab.paddingH
            if (cfg.tab?.paddingV           !== undefined) tabPaddingV           = cfg.tab.paddingV
            if (cfg.tab?.radius             !== undefined) tabRadius             = cfg.tab.radius
            if (cfg.tab?.maxHeight          !== undefined) tabMaxHeight          = cfg.tab.maxHeight
            if (cfg.tab?.collapsedHeight    !== undefined) tabCollapsedHeight    = cfg.tab.collapsedHeight
            if (cfg.tab?.bgOpacity         !== undefined) tabBgOpacity         = cfg.tab.bgOpacity
            if (cfg.island?.paddingH        !== undefined) islandPaddingH        = cfg.island.paddingH
            if (cfg.island?.paddingV        !== undefined) islandPaddingV        = cfg.island.paddingV
            if (cfg.island?.gap             !== undefined) islandGap             = cfg.island.gap
            if (cfg.island?.blur            !== undefined) islandBlur            = cfg.island.blur
            if (cfg.island?.bgOpacity       !== undefined) islandBgOpacity       = cfg.island.bgOpacity
            if (cfg.island?.borderOpacity   !== undefined) islandBorderOpacity   = cfg.island.borderOpacity
            if (cfg.island?.chipRadius               !== undefined) islandChipRadius               = cfg.island.chipRadius
            if (cfg.island?.activeFillOpacity        !== undefined) islandActiveFillOpacity        = cfg.island.activeFillOpacity
            if (cfg.island?.stateLayerHoverOpacity   !== undefined) islandStateLayerHoverOpacity   = cfg.island.stateLayerHoverOpacity
            if (cfg.island?.stateLayerPressedOpacity !== undefined) islandStateLayerPressedOpacity = cfg.island.stateLayerPressedOpacity
            if (cfg.island?.semanticGap              !== undefined) islandSemanticGap              = cfg.island.semanticGap
            if (cfg.island?.separatorWidth           !== undefined) islandSeparatorWidth           = cfg.island.separatorWidth
            if (cfg.island?.powerTintOpacity         !== undefined) islandPowerTintOpacity         = cfg.island.powerTintOpacity
            if (cfg.ornament?.opacity       !== undefined) ornamentOpacity       = cfg.ornament.opacity
            if (cfg.ornament?.stroke        !== undefined) ornamentStroke        = cfg.ornament.stroke
            if (cfg.anim?.fast       !== undefined) animFast       = cfg.anim.fast
            if (cfg.anim?.normal     !== undefined) animNormal     = cfg.anim.normal
            if (cfg.anim?.slow       !== undefined) animSlow       = cfg.anim.slow
            if (cfg.anim?.enabled    !== undefined) animationsEnabled = cfg.anim.enabled !== false
            if (cfg.anim?.overrides  !== undefined && typeof cfg.anim.overrides === "object") animationOverrides = cfg.anim.overrides
            // Clamp the scale: a zero, negative, or absurd multiplier would
            // turn the shell's motion into either no motion or a stall. Values
            // that do not parse to a positive number are ignored outright, so a
            // malformed entry cannot silently replace the timing defaults.
            if (cfg.anim?.scale !== undefined) {
                const scale = Number(cfg.anim.scale)
                if (Number.isFinite(scale) && scale > 0)
                    animScale = Math.min(3.0, Math.max(0.25, scale))
            }
            if (cfg.font?.caption    !== undefined) fontSizeCaption = cfg.font.caption
            if (cfg.font?.label      !== undefined) fontSizeLabel   = cfg.font.label
            if (cfg.font?.body       !== undefined) fontSizeBody    = cfg.font.body
            if (cfg.font?.bodyLg     !== undefined) fontSizeBodyLg  = cfg.font.bodyLg
            if (cfg.font?.icon       !== undefined) fontSizeIcon    = cfg.font.icon
            if (cfg.wallpaper?.overlayDuration !== undefined) {
                const overlayDuration = Number(cfg.wallpaper.overlayDuration)
                if (Number.isFinite(overlayDuration)) wallpaperOverlayDuration = Math.max(1, Math.round(overlayDuration))
            }
            if (cfg.wallpaper?.previewDelay !== undefined) {
                const previewDelay = Number(cfg.wallpaper.previewDelay)
                if (Number.isFinite(previewDelay)) wallpaperPreviewDelay = Math.max(0, Math.round(previewDelay))
            }
            if (cfg.wallpaper?.transition !== undefined) wallpaperTransition = String(cfg.wallpaper.transition)
            if (cfg.wallpaper?.duration !== undefined) {
                const duration = Number(cfg.wallpaper.duration)
                if (Number.isFinite(duration)) wallpaperTransitionDuration = Math.max(0.1, duration)
            }
            if (cfg.wallpaper?.fps !== undefined) {
                const fps = Number(cfg.wallpaper.fps)
                if (Number.isFinite(fps)) wallpaperTransitionFps = Math.max(1, Math.round(fps))
            }
            if (cfg.wallpaper?.step !== undefined) {
                const step = Number(cfg.wallpaper.step)
                if (Number.isFinite(step)) wallpaperTransitionStep = Math.max(1, Math.round(step))
            }
            if (cfg.dashboard?.railWidth !== undefined) dashboardRailWidth = cfg.dashboard.railWidth
            if (cfg.dashboard?.bodyRadius       !== undefined) dashboardBodyRadius       = cfg.dashboard.bodyRadius
            if (cfg.dashboard?.bodyOpacity      !== undefined) dashboardBodyOpacity      = cfg.dashboard.bodyOpacity
            if (cfg.dashboard?.bodyBorderWidth  !== undefined) dashboardBodyBorderWidth  = cfg.dashboard.bodyBorderWidth
            if (cfg.dashboard?.bodyPadding      !== undefined) dashboardBodyPadding      = cfg.dashboard.bodyPadding
            if (cfg.dashboard?.tabHeight        !== undefined) dashboardTabHeight        = cfg.dashboard.tabHeight
            if (cfg.dashboard?.tabSpacing       !== undefined) dashboardTabSpacing       = cfg.dashboard.tabSpacing
            if (cfg.dashboard?.cardHeight       !== undefined) dashboardCardHeight       = cfg.dashboard.cardHeight
            if (cfg.dashboard?.cardGap          !== undefined) dashboardCardGap          = cfg.dashboard.cardGap
            if (cfg.dashboard?.progressHeight   !== undefined) dashboardProgressHeight   = cfg.dashboard.progressHeight
            if (cfg.dashboard?.progressRadius   !== undefined) dashboardProgressRadius   = cfg.dashboard.progressRadius
            if (cfg.dashboard?.sparklineWidth   !== undefined) dashboardSparklineWidth   = cfg.dashboard.sparklineWidth
            if (cfg.dashboard?.sparklineHeight  !== undefined) dashboardSparklineHeight  = cfg.dashboard.sparklineHeight
            if (cfg.dashboard?.footerHeight     !== undefined) dashboardFooterHeight     = cfg.dashboard.footerHeight
            const surfaceCfg = cfg.surface || cfg.rightPanel
            if (surfaceCfg?.mode !== undefined) {
                const mode = String(surfaceCfg.mode)
                surfaceMode = ["solid", "translucent", "glass"].indexOf(mode) >= 0 ? mode : "solid"
            }
            if (surfaceCfg?.nativeBlur !== undefined)
                nativeBlur = surfaceCfg.nativeBlur === true
            if (surfaceCfg?.islandNativeBlur !== undefined)
                islandNativeBlur = surfaceCfg.islandNativeBlur === true
            if (surfaceCfg?.islandNativePrototypeTarget !== undefined) {
                const nativeTarget = String(surfaceCfg.islandNativePrototypeTarget)
                islandNativePrototypeTarget = ["none", "left"].indexOf(nativeTarget) >= 0
                    ? nativeTarget : "none"
            }
            if (surfaceCfg?.islandNativePrototypeScreen !== undefined)
                islandNativePrototypeScreen = typeof surfaceCfg.islandNativePrototypeScreen === "string"
                    ? surfaceCfg.islandNativePrototypeScreen : ""
            if (surfaceCfg?.islandGpuPrototypeTarget !== undefined) {
                const prototypeTarget = String(surfaceCfg.islandGpuPrototypeTarget)
                islandGpuPrototypeTarget = ["none", "left"].indexOf(prototypeTarget) >= 0
                    ? prototypeTarget : "none"
            }
            if (surfaceCfg?.opacity !== undefined) {
                const opacity = Number(surfaceCfg.opacity)
                if (Number.isFinite(opacity))
                    surfaceOpacity = Math.min(1.0, Math.max(0.0, opacity))
            }
            if (surfaceCfg?.cardOpacity !== undefined) {
                const cardOpacity = Number(surfaceCfg.cardOpacity)
                if (Number.isFinite(cardOpacity))
                    surfaceCardOpacity = Math.min(1.0, Math.max(0.0, cardOpacity))
            }
            if (surfaceCfg?.nestedOpacity !== undefined) {
                const nestedOpacity = Number(surfaceCfg.nestedOpacity)
                if (Number.isFinite(nestedOpacity))
                    surfaceNestedOpacity = Math.min(1.0, Math.max(0.0, nestedOpacity))
            }
            if (surfaceCfg?.overlayOpacity !== undefined) {
                const overlayOpacity = Number(surfaceCfg.overlayOpacity)
                if (Number.isFinite(overlayOpacity))
                    surfaceOverlayOpacity = Math.min(1.0, Math.max(0.0, overlayOpacity))
            }
            if (cfg.button?.primaryTone !== undefined) {
                const tone = Number(cfg.button.primaryTone)
                if (Number.isFinite(tone)) buttonPrimaryTone = Math.min(1.0, Math.max(0.0, tone))
            }
            if (cfg.button?.secondaryTone !== undefined) {
                const tone = Number(cfg.button.secondaryTone)
                if (Number.isFinite(tone)) buttonSecondaryTone = Math.min(1.0, Math.max(0.0, tone))
            }
            if (cfg.button?.hoverLift !== undefined) {
                const lift = Number(cfg.button.hoverLift)
                if (Number.isFinite(lift)) buttonHoverLift = Math.min(1.0, Math.max(0.0, lift))
            }
            if (cfg.button?.pressedLift !== undefined) {
                const lift = Number(cfg.button.pressedLift)
                if (Number.isFinite(lift)) buttonPressedLift = Math.min(1.0, Math.max(0.0, lift))
            }
            if (cfg.rightPanel?.width       !== undefined) rightPanelWidth       = cfg.rightPanel.width
            if (cfg.rightPanel?.powerWidth  !== undefined) rightPanelPowerWidth  = cfg.rightPanel.powerWidth
            if (cfg.rightPanel?.maxHeight   !== undefined) rightPanelMaxHeight   = cfg.rightPanel.maxHeight
            if (cfg.rightPanel?.topMargin   !== undefined) rightPanelTopMargin   = cfg.rightPanel.topMargin
            if (cfg.rightPanel?.rightMargin !== undefined) rightPanelRightMargin = cfg.rightPanel.rightMargin
            if (cfg.rightPanel?.padding     !== undefined) rightPanelPadding     = cfg.rightPanel.padding
            if (cfg.rightPanel?.cardGap     !== undefined) rightPanelCardGap     = cfg.rightPanel.cardGap
            if (!cfg.surface && cfg.rightPanel?.cardFillOpacity !== undefined) {
                const cardOpacity = Number(cfg.rightPanel.cardFillOpacity)
                if (Number.isFinite(cardOpacity))
                    surfaceCardOpacity = Math.min(1.0, Math.max(0.0, cardOpacity))
            }
            const panel = cfg.panel
            if (panel && panel.accentSeamWidth   !== undefined) accentSeamWidth        = panel.accentSeamWidth
            if (panel && panel.volumeTrackHeight !== undefined) panelVolumeTrackHeight = panel.volumeTrackHeight
            if (panel && panel.secondarySeamWidth !== undefined) panelSecondarySeamWidth = panel.secondarySeamWidth
            if (cfg.debug?.visualBounds  !== undefined) debugVisualBounds  = cfg.debug.visualBounds
            if (cfg.debug?.borderColor   !== undefined) debugBorderColor   = cfg.debug.borderColor
            if (cfg.debug?.borderWidth   !== undefined) debugBorderWidth   = cfg.debug.borderWidth
            if (cfg.debug?.barSilhouette !== undefined) debugBarSilhouette = cfg.debug.barSilhouette
        } catch(e) {}
    }

    Component.onCompleted: {
        applyConfig()
        debounce.restart()
    }
}
