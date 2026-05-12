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

    // Ornament
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
            if (cfg.bar?.height      !== undefined) barHeight      = cfg.bar.height
            if (cfg.ornament?.opacity !== undefined) ornamentOpacity = cfg.ornament.opacity
            if (cfg.ornament?.stroke  !== undefined) ornamentStroke  = cfg.ornament.stroke
            if (cfg.anim?.fast       !== undefined) animFast       = cfg.anim.fast
            if (cfg.anim?.normal     !== undefined) animNormal     = cfg.anim.normal
            if (cfg.anim?.slow       !== undefined) animSlow       = cfg.anim.slow
            if (cfg.font?.caption    !== undefined) fontSizeCaption = cfg.font.caption
            if (cfg.font?.label      !== undefined) fontSizeLabel   = cfg.font.label
            if (cfg.font?.body       !== undefined) fontSizeBody    = cfg.font.body
            if (cfg.font?.bodyLg     !== undefined) fontSizeBodyLg  = cfg.font.bodyLg
            if (cfg.font?.icon       !== undefined) fontSizeIcon    = cfg.font.icon
        } catch(e) {}
    }

    Component.onCompleted: applyConfig()
}
