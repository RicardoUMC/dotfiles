# Spec: Theme System

## Description

Mutable `Theme.qml` singleton providing structural design tokens (radius, spacing, opacity, bar geometry, bar screen selection, dashboard geometry, control-center panel chrome, tab geometry, debug scaffolding, animation durations, font sizes) with hot-reload via `config.json`. Complements the static `Colors.qml` palette — colors are not part of this system.

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
| Bar | `barChipHeight` | `30` | `int` |
| Bar | `barCurveRadius` | `14` | `int` |
| Bar | `barWrapDepth` | `14` | `int` |
| Bar | `centerCollapsedWidth` | `360` | `int` |
| Bar | `centerExpandedWidth` | `520` | `int` |
| Bar | `centerExpandedHeight` | `260` | `int` |
| Bar | `dashboardRailWidth` | `44` | `int` |
| Bar | `dashboardBodyRadius` | `10` | `int` |
| Bar | `dashboardBodyOpacity` | `0.35` | `real` |
| Bar | `dashboardBodyBorderWidth` | `1` | `int` |
| Bar | `dashboardBodyPadding` | `12` | `int` |
| Bar | `dashboardTabHeight` | `40` | `int` |
| Bar | `dashboardTabSpacing` | `8` | `int` |
| Bar | `dashboardCardHeight` | `42` | `int` |
| Bar | `dashboardCardGap` | `4` | `int` |
| Bar | `dashboardProgressHeight` | `4` | `int` |
| Bar | `dashboardProgressRadius` | `2` | `int` |
| Bar | `dashboardSparklineWidth` | `80` | `int` |
| Bar | `dashboardSparklineHeight` | `32` | `int` |
| Bar | `dashboardFooterHeight` | `18` | `int` |
| Bar | `barStyle` | `"silhouette"` | `string` |
| Bar | `barScreens` | `"all"` | `var` |
| Bar | `barNotchGapWidth` | `30` | `real` |
| Bar | `barNotchDepthRatio` | `0.2` | `real` |
| Panel chrome | `accentSeamWidth` | `4` | `int` |
| Panel chrome | `panelSecondarySeamWidth` | `2` | `int` |
| Panel chrome | `panelVolumeTrackHeight` | `8` | `int` |
| Panel chrome | `rightPanelOpacity` | `0.94` | `real` |
| Animation | `animFast` | `180` | `int` (ms) |
| Animation | `animNormal` | `300` | `int` (ms) |
| Animation | `animSlow` | `500` | `int` (ms) |
| Font size | `fontSizeCaption` | `12` | `int` |
| Font size | `fontSizeLabel` | `13` | `int` |
| Font size | `fontSizeBody` | `15` | `int` |
| Font size | `fontSizeBodyLg` | `17` | `int` |
| Font size | `fontSizeIcon` | `22` | `int` |

Panel-chrome tokens map to `config.json` keys as follows: `accentSeamWidth` ← `panel.accentSeamWidth`, `panelSecondarySeamWidth` ← `panel.secondarySeamWidth`, `panelVolumeTrackHeight` ← `panel.volumeTrackHeight`, `rightPanelOpacity` ← `rightPanel.opacity`. `barScreens` ← `bar.screens`, `barNotchGapWidth` ← `bar.notchGapWidth`, `barNotchDepthRatio` ← `bar.notchDepthRatio`. A legacy `bar.curveDepthRatio` key still feeds the deprecated `barCurveDepthRatio` alias and acts as a fallback for `barNotchDepthRatio`.

Additional implemented groups include tab geometry (`tabPaddingH`, `tabPaddingV`, `tabRadius`, `tabMaxHeight`, `tabCollapsedHeight`, `tabBgOpacity`), island/ornament experimental tokens, and debug scaffolding (`debugVisualBounds`, `debugBorderColor`, `debugBorderWidth`, `debugBarSilhouette`).

### Requirement: Colors.qml Unchanged

`Colors.qml` remains a separate readonly singleton for color/font-family tokens. It is NOT part of the theme system.

### Requirement: Zero Visual Regression

All migrated components produce stable visual output with default token values. `barHeight` (37) is used for overlay offsets, while current bar content sizing uses `barChipHeight`, tab padding, and measured island implicit heights.

### Requirement: Wrapped Bar Silhouette Tokens

`Bar.qml` uses `barCurveRadius` as the shared corner curvature source and `barWrapDepth` as an independent decorative downward wrap depth. The panel `exclusiveZone` reserves only the measured interactive content height, not the full decorative silhouette height. The center notch uses `centerCollapsedWidth`, `centerExpandedWidth`, and `centerExpandedHeight` to grow in place into a dashboard without increasing reserved Hyprland space. `Bar.qml` uses dashboard body tokens for the expanded body radius, opacity, border width, and padding. `CenterDashboard.qml` uses dashboard rail/tab tokens. `MetricsPane.qml` and `MetricCard.qml` use dashboard card, progress, sparkline, and footer tokens.

### Requirement: Panel Chrome Seam Separation

The control-center panel-chrome family has three deliberately distinct seam/track tokens. They must not be merged with each other or with dashboard geometry:

- `accentSeamWidth` (`4`, `panel.accentSeamWidth`) — the hero accent seam of the three specialty cards (`WifiControlCard.qml`, `BluetoothControlCard.qml`, `AudioControlCard.qml` hero blocks).
- `panelSecondarySeamWidth` (`2`, `panel.secondarySeamWidth`) — the accent seam of the nested audio device panel (`AudioControlPanel.qml`), intentionally thinner than the hero seam.
- `panelVolumeTrackHeight` (`8`, `panel.volumeTrackHeight`) — the Audio card volume track thickness and knob diameter (`AudioControlCard.qml`).

`dashboardProgressHeight` belongs to center-dashboard metric bars (`MetricCard.qml`) only and is no longer reused as seam geometry anywhere. The hero seam sharing the numeric value `4` with `dashboardProgressHeight` is coincidence, not coupling.

`rightPanelOpacity` (`0.94`, `rightPanel.opacity`) drives only the outer background of the right control-center surface (`RightControlCenter.qml`); inner specialty cards and slabs keep their own subtle translucency and are NOT bound to this token.

### Requirement: Bar Screen Selection

`barScreens` (`var`, default `"all"`, `config.json` key `bar.screens`) resolves which connected screens get a `Bar` instance. The selector lives in `shell.qml` (`screenSelector.enabledScreens`), which feeds the per-screen `Variants { model: ... }` that instantiates `Bar.qml`.

- Accepted values: the string `"all"`, or an array of `ShellScreen.name` strings (e.g. `["DP-1"]`).
- Matching is by screen **name only** — never by index or ordering.
- Names that match no connected screen are ignored.
- If the resolved set comes out empty (typo'd or unplugged name), the shell falls back to ALL screens so a session is never left without a bar.
- The binding re-evaluates on `Quickshell.screens` changes, so hot-plug adds and removes bar instances without a reload.

One-bar-per-screen architecture, per-screen surface ownership, and overlay coordination are specified in `specs/multi-monitor.md`; this spec covers only the token contract.

### Requirement: Hot-Reload via config.json

`Theme.qml` watches `~/.config/quickshell/config.json` via `FileView` with `watchChanges: true`. On file change, `FileView.reload()` refreshes the text content before a 100ms debounce `Timer` fires and re-parses the config, preventing reactions to partial writes while still applying live edits. Missing file uses defaults silently.

### Requirement: Robust Configuration Parsing

`config.json` is parsed with `JSON.parse` inside a `try/catch`. Invalid JSON fails silently — all tokens retain their current values. Only explicitly provided keys are applied (partial overrides); unset keys keep defaults.

---

## config.json Schema

Every key `Theme.applyConfig()` accepts, with the value it currently resolves to in this repo (defaults where `config.json` omits the key):

```json
{
  "radius":  { "sm": 6,    "md": 10,   "lg": 12,   "pill": 999 },
  "spacing": { "xs": 4,    "sm": 8,    "md": 12,  "lg": 16, "xl": 24 },
  "opacity": { "surface": 0.97, "overlay": 0.33, "border": 0.30, "dim": 0.15 },
  "bar":     { "height": 37, "style": "silhouette", "screens": "all", "chipHeight": 30, "curveRadius": 16, "wrapDepth": 12, "notchGapWidth": 30, "notchDepthRatio": 0.2, "centerCollapsedWidth": 360, "centerExpandedWidth": 520, "centerExpandedHeight": 260 },
  "dashboard": { "railWidth": 44, "bodyRadius": 10, "bodyOpacity": 0.35, "bodyBorderWidth": 1, "bodyPadding": 12, "tabHeight": 40, "tabSpacing": 8, "cardHeight": 42, "cardGap": 4, "progressHeight": 4, "progressRadius": 2, "sparklineWidth": 80, "sparklineHeight": 32, "footerHeight": 18 },
  "panel":   { "accentSeamWidth": 4, "secondarySeamWidth": 2, "volumeTrackHeight": 8 },
  "rightPanel": { "opacity": 0.94 },
  "anim":    { "fast": 180, "normal": 300, "slow": 500 },
  "font":    { "caption": 12, "label": 13, "body": 15, "bodyLg": 17, "icon": 22 },
  "debug":   { "visualBounds": false, "borderColor": "#ff3344", "borderWidth": 1, "barSilhouette": false }
}
```

The committed `config.json` currently overrides only two tokens away from their `Theme.qml` defaults: `bar.curveRadius` `14` → `16` and `bar.wrapDepth` `14` → `12`. It omits the `bar.center*` keys, which therefore resolve to their inline defaults shown above.

Location in this stow-managed repo: `quickshell/.config/quickshell/config.json`, which maps to `~/.config/quickshell/config.json`.

---

## Hot-Reload Behavior

```
config.json ──(write)──→ FileView.onFileChanged
                               │
                          FileView.reload()
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
- **Reload before debounce**: `FileView.onFileChanged` calls `reload()` before restarting the debounce so `configFile.text()` is fresh when `applyConfig()` runs
- **Debounce**: 100ms `Timer`, restarted on each `fileChanged` signal
- **Silent fail**: `try/catch` around `JSON.parse` — no crash, no log on malformed JSON
- **Partial override**: each token guarded independently (`if (cfg.radius?.sm !== undefined)`)
- **Initial load**: `Component.onCompleted` calls `applyConfig()` once at startup

Dashboard overrides are grouped under `dashboard.*` in `config.json` but exposed to QML consumers as flat `Theme.dashboardXxx` properties to match the existing `Theme.applyConfig()` pattern. Defaults preserve the implemented center-dashboard layout; extreme size overrides can overflow unless `centerExpandedWidth` and `centerExpandedHeight` are tuned together.

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

### Scenario: Bar Screen Selection By Name

- **GIVEN** `config.json` sets `bar.screens` to an array such as `["DP-1"]`
- **WHEN** `shell.qml` resolves `screenSelector.enabledScreens`
- **THEN** exactly the connected screens whose `ShellScreen.name` matches get a `Bar` instance, regardless of monitor index or ordering, and unmatched names are ignored

### Scenario: Bar Screen Selection Falls Back To All

- **GIVEN** `config.json` sets `bar.screens` to an array whose names match no connected screen
- **WHEN** the resolved set comes out empty
- **THEN** every connected screen gets a bar, so the session is never left without one

### Scenario: Dashboard Structural Overrides

- **GIVEN** `config.json` contains dashboard structural overrides such as `dashboard.bodyPadding`, `dashboard.cardHeight`, or `dashboard.sparklineWidth`
- **WHEN** `Theme.qml` parses the config at startup or after hot-reload
- **THEN** the matching flat `Theme.dashboardXxx` properties update and bound dashboard components re-render without requiring new QML types
