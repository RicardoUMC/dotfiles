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
    property int barChipHeight: 26
    property int barCurveRadius: 14
    property int barWrapDepth: 14
    property int centerCollapsedWidth: 360
    property int centerExpandedWidth: 520
    property int centerExpandedHeight: 260
    property int dashboardRailWidth: 44
    property string barStyle: "silhouette"         // "silhouette" | "plain"
    property real barCurveDepthRatio: 0.2           // concave depth = height × ratio (legacy, use barNotchDepthRatio)
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

    // Ornament (Variant A & B)
    property real ornamentOpacity: 0.07
    property real ornamentStroke:  1.5

    // Animation (ms)
    property int animFast:   180
    property int animNormal: 300
    property int animSlow:   500

    // Font sizes
    property int fontSizeCaption: 10
    property int fontSizeLabel:   11
    property int fontSizeBody:    13
    property int fontSizeBodyLg:  14
    property int fontSizeIcon:    18

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
        onFileChanged: debounce.restart()
    }

    function applyConfig() {
        try {
            const cfg = JSON.parse(configFile.text())
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
            if (cfg.bar?.centerCollapsedWidth !== undefined) centerCollapsedWidth = cfg.bar.centerCollapsedWidth
            if (cfg.bar?.centerExpandedWidth  !== undefined) centerExpandedWidth  = cfg.bar.centerExpandedWidth
            if (cfg.bar?.centerExpandedHeight !== undefined) centerExpandedHeight = cfg.bar.centerExpandedHeight
            if (cfg.bar?.style !== undefined) {
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
            if (cfg.ornament?.opacity       !== undefined) ornamentOpacity       = cfg.ornament.opacity
            if (cfg.ornament?.stroke        !== undefined) ornamentStroke        = cfg.ornament.stroke
            if (cfg.anim?.fast       !== undefined) animFast       = cfg.anim.fast
            if (cfg.anim?.normal     !== undefined) animNormal     = cfg.anim.normal
            if (cfg.anim?.slow       !== undefined) animSlow       = cfg.anim.slow
            if (cfg.font?.caption    !== undefined) fontSizeCaption = cfg.font.caption
            if (cfg.font?.label      !== undefined) fontSizeLabel   = cfg.font.label
            if (cfg.font?.body       !== undefined) fontSizeBody    = cfg.font.body
            if (cfg.font?.bodyLg     !== undefined) fontSizeBodyLg  = cfg.font.bodyLg
            if (cfg.font?.icon       !== undefined) fontSizeIcon    = cfg.font.icon
            if (cfg.dashboard?.railWidth !== undefined) dashboardRailWidth = cfg.dashboard.railWidth
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
