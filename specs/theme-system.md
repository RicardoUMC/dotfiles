# Spec: Theme System

## Description

Mutable `Theme.qml` singleton providing structural design tokens (radius, spacing, opacity, bar geometry, tab geometry, debug scaffolding, animation durations, font sizes) with hot-reload via `config.json`. Complements the static `Colors.qml` palette — colors are not part of this system.

---

## Requirements

### Requirement: Theme.qml Singleton Structure

`Theme.qml` is a mutable `pragma Singleton` importable from any component. All token properties declare their safe default values inline (not in `Component.onCompleted`) to guarantee a valid first frame.

### Requirement: Core Token Catalog

Core structural tokens with their defaults:

| Group | Token | Default | Type |
|-------|-------|---------|------|
| Radius | `radiusSm` | `6` | `int` |
| Radius | `radiusMd` | `10` | `int` |
| Radius | `radiusLg` | `12` | `int` |
| Radius | `radiusPill` | `999` | `int` |
| Spacing | `spacingXs` | `4` | `int` |
| Spacing | `spacingSm` | `8` | `int` |
| Spacing | `spacingMd` | `12` | `int` |
| Spacing | `spacingLg` | `16` | `int` |
| Spacing | `spacingXl` | `24` | `int` |
| Opacity | `opacitySurface` | `0.97` | `real` |
| Opacity | `opacityOverlay` | `0.33` | `real` |
| Opacity | `opacityBorder` | `0.30` | `real` |
| Opacity | `opacityDim` | `0.15` | `real` |
| Bar | `barHeight` | `37` | `int` |
| Bar | `barChipHeight` | `26` | `int` |
| Bar | `barCurveRadius` | `14` | `int` |
| Bar | `barWrapDepth` | `14` | `int` |
| Bar | `centerCollapsedWidth` | `360` | `int` |
| Bar | `centerExpandedWidth` | `520` | `int` |
| Bar | `centerExpandedHeight` | `260` | `int` |
| Bar | `dashboardRailWidth` | `44` | `int` |
| Bar | `barStyle` | `"silhouette"` | `string` |
| Animation | `animFast` | `180` | `int` (ms) |
| Animation | `animNormal` | `300` | `int` (ms) |
| Animation | `animSlow` | `500` | `int` (ms) |
| Font size | `fontSizeCaption` | `10` | `int` |
| Font size | `fontSizeLabel` | `11` | `int` |
| Font size | `fontSizeBody` | `13` | `int` |
| Font size | `fontSizeBodyLg` | `14` | `int` |
| Font size | `fontSizeIcon` | `18` | `int` |

Additional implemented groups include tab geometry (`tabPaddingH`, `tabPaddingV`, `tabRadius`, `tabMaxHeight`, `tabCollapsedHeight`, `tabBgOpacity`), island/ornament experimental tokens, and debug scaffolding (`debugVisualBounds`, `debugBorderColor`, `debugBorderWidth`, `debugBarSilhouette`).

### Requirement: Colors.qml Unchanged

`Colors.qml` remains a separate readonly singleton for color/font-family tokens. It is NOT part of the theme system.

### Requirement: Zero Visual Regression

All migrated components produce stable visual output with default token values. `barHeight` (37) is used for overlay offsets, while current bar content sizing uses `barChipHeight`, tab padding, and measured island implicit heights.

### Requirement: Wrapped Bar Silhouette Tokens

`Bar.qml` uses `barCurveRadius` as the shared corner curvature source and `barWrapDepth` as an independent decorative downward wrap depth. The panel `exclusiveZone` reserves only the measured interactive content height, not the full decorative silhouette height. The center notch uses `centerCollapsedWidth`, `centerExpandedWidth`, and `centerExpandedHeight` to grow in place into a dashboard without increasing reserved Hyprland space. `CenterDashboard.qml` uses `dashboardRailWidth` for the vertical tab rail width.

### Requirement: Hot-Reload via config.json

`Theme.qml` watches `~/.config/quickshell/config.json` via `FileView` with `watchChanges: true`. On file change, a 100ms debounce `Timer` fires before re-parsing, preventing reactions to partial writes. Missing file uses defaults silently.

### Requirement: Robust Configuration Parsing

`config.json` is parsed with `JSON.parse` inside a `try/catch`. Invalid JSON fails silently — all tokens retain their current values. Only explicitly provided keys are applied (partial overrides); unset keys keep defaults.

---

## config.json Schema

All fields optional. Missing fields keep defaults.

```json
{
  "radius":  { "sm": 6,    "md": 10,   "lg": 12  },
  "spacing": { "xs": 4,    "sm": 8,    "md": 12,  "lg": 16, "xl": 24 },
  "opacity": { "surface": 0.97, "overlay": 0.33, "border": 0.30, "dim": 0.15 },
  "bar":     { "height": 37, "style": "silhouette", "chipHeight": 26, "curveRadius": 14, "wrapDepth": 14, "centerCollapsedWidth": 360, "centerExpandedWidth": 520, "centerExpandedHeight": 260 },
  "dashboard": { "railWidth": 44 },
  "anim":    { "fast": 180, "normal": 300, "slow": 500 },
  "font":    { "caption": 10, "label": 11, "body": 13, "bodyLg": 14, "icon": 18 },
  "debug":   { "visualBounds": false, "borderColor": "#ff3344", "borderWidth": 1, "barSilhouette": false }
}
```

Location in this stow-managed repo: `quickshell/.config/quickshell/config.json`, which maps to `~/.config/quickshell/config.json`.

---

## Hot-Reload Behavior

```
config.json ──(write)──→ FileView.onFileChanged
                               │
                          Timer.restart()  ← 100ms debounce
                               │
                          Timer.onTriggered
                               │
                          applyConfig()
                               │
                    Theme.token = cfg.group.key  (per-key guards)
                               │
                    All bound components re-render
```

- **watchChanges**: `FileView.watchChanges: true`
- **Debounce**: 100ms `Timer`, restarted on each `fileChanged` signal
- **Silent fail**: `try/catch` around `JSON.parse` — no crash, no log on malformed JSON
- **Partial override**: each token guarded independently (`if (cfg.radius?.sm !== undefined)`)
- **Initial load**: `Component.onCompleted` calls `applyConfig()` once at startup

---

## Scenarios

### Scenario: Absent Configuration File

- **GIVEN** `config.json` is absent
- **WHEN** Quickshell starts
- **THEN** all tokens use their inline defaults and the app does not crash

### Scenario: Partial Configuration Overrides

- **GIVEN** `config.json` contains a subset of token keys
- **WHEN** the config is parsed
- **THEN** only specified tokens change; the rest keep defaults

### Scenario: Invalid JSON Configuration

- **GIVEN** `config.json` contains invalid JSON
- **WHEN** the file is parsed
- **THEN** parsing fails silently and all tokens retain their current values

### Scenario: Live Configuration Update

- **GIVEN** `config.json` is written while Quickshell is running
- **WHEN** the 100ms debounce fires
- **THEN** tokens update and the UI reflects the new values within ~200ms

### Scenario: Reactive Component Token Reading

- **GIVEN** a component is bound to a token (e.g., `Theme.radiusSm`)
- **WHEN** the token updates via hot-reload
- **THEN** the component immediately receives and applies the new value
