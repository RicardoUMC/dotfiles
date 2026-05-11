# Design: Theme System

## Technical Approach

Introduce `Theme.qml` as a mutable `pragma Singleton` alongside the existing readonly `Colors.qml`. All configurable non-color tokens live in `Theme.qml` with hardcoded defaults. An optional `config.json` can override any token at runtime via `FileView` hot-reload. Migrate 12 consumer files to reference `Theme.*` instead of magic numbers, in phased order from least to most risky.

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|-------------|-----------|
| Singleton mutability | Mutable properties (no `readonly`) | Signals + property binding injection | Direct property assignment from JS is the simplest QML pattern; works in Quickshell without engine tricks |
| Colors.qml | Keep unchanged | Merge into Theme.qml | Colors is a static palette — separation of concerns; palette swapping is a different future change |
| Config file location | `~/.config/quickshell/config.json` | Inside stow repo | User-editable runtime file must NOT be stow-managed; lives outside dotfiles repo |
| Hot-reload debounce | 100ms Timer restarted on `fileChanged` | Direct `onFileChanged` parse | Editors write files in multiple chunks; debounce prevents parsing partial JSON |
| Defaults placement | Property declarations (not `onCompleted`) | `onCompleted` only | First QML frame renders before `onCompleted` fires — defaults in declarations guarantee valid initial state |

## Data Flow

```
config.json ──(write)──→ FileView.onFileChanged
                               │
                          Timer.restart()
                               │ (100ms debounce)
                          Timer.onTriggered
                               │
                          applyConfig()
                               │
                    Theme.radiusSm = cfg.radius.sm
                    Theme.barHeight = cfg.bar.height
                    ...
                               │
                    All bound components re-render
```

## File Changes

| File | Action | Tokens needed |
|------|--------|--------------|
| `theme/Theme.qml` | **Create** | — (the singleton itself) |
| `theme/qmldir` | **Modify** | Add singleton registration |
| `bar/SystemStats.qml` | Modify | radius, opacity, fontSizes |
| `bar/Workspaces.qml` | Modify | radius, opacity |
| `bar/MprisIndicator.qml` | Modify | radius, opacity, animFast |
| `bar/MprisPopup.qml` | Modify | radius, opacity, animFast, spacing |
| `bar/PowerMenu.qml` | Modify | radius, opacity, spacing, **barHeight** |
| `bar/PowerMenuItem.qml` | Modify | radius, opacity, spacing |
| `bar/Bar.qml` | Modify | **barHeight**, spacing |
| `launcher/LauncherCentered.qml` | Modify | radius, opacity, spacing, fontSizes |
| `notifications/NotificationToast.qml` | Modify | radius, opacity, animNormal, spacing, fontSizes |
| `notifications/Notifications.qml` | Modify | **barHeight**, spacing |

## Theme.qml Structure

```qml
pragma Singleton
import QtQuick
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
        path: Quickshell.configDir + "/config.json"
        watchFiles: true
        onFileChanged: debounce.restart()
    }

    function applyConfig() {
        try {
            const cfg = JSON.parse(configFile.text())
            if (cfg.radius?.sm   !== undefined) radiusSm   = cfg.radius.sm
            if (cfg.radius?.md   !== undefined) radiusMd   = cfg.radius.md
            if (cfg.radius?.lg   !== undefined) radiusLg   = cfg.radius.lg
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
```

## config.json Schema

```json
{
  "radius":  { "sm": 6,    "md": 10,   "lg": 12  },
  "spacing": { "xs": 4,    "sm": 8,    "md": 12,  "lg": 16, "xl": 24 },
  "opacity": { "surface": 0.97, "overlay": 0.33, "border": 0.30, "dim": 0.15 },
  "bar":     { "height": 37 },
  "anim":    { "fast": 180, "normal": 300, "slow": 500 },
  "font":    { "caption": 10, "label": 11, "body": 13, "bodyLg": 14, "icon": 18 }
}
```

All fields are optional. Missing fields keep their default values.

## Migration Order

1. Create `Theme.qml` + register in `qmldir` — no consumer changes yet
2. `SystemStats.qml` — most isolated, good smoke test
3. `Workspaces.qml`, `MprisIndicator.qml`
4. `MprisPopup.qml`, `PowerMenu.qml`, `PowerMenuItem.qml`
5. `LauncherCentered.qml`, `NotificationToast.qml`
6. `barHeight` in `Bar.qml` + `Notifications.qml` + `PowerMenu.qml` — critical, last
7. Add `FileView` + `Timer` debounce + `applyConfig()` to `Theme.qml`

## Open Questions

- None. Design is complete and unblocked.
