# Bar

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/bar/Bar.qml`, `BarTab.qml`, `BarSection.qml`, `NotchIslandMask.qml`, `NotchCornerMask.qml`, `Workspaces.qml`, `ServiceEndpoint.qml`, `ServiceDivider.qml`, `ClockChip.qml`, `MprisIndicator.qml`, `RightIslandIconButton.qml`, `StateLayer.qml`, `RightControlCenter.qml`, `PowerMenu.qml`, instantiation in `shell.qml`

## Description

Per-screen floating bar composed of independent wrapped-silhouette islands. Each `Bar` resolves its exact-name position through `Theme.effectiveBarConfig(screenName)` and supports top, bottom, left, and right edges; it coordinates the overlay state of the surfaces it owns and expands the center island in place into a lightweight dashboard.

## Future evolution

The configurable-bar foundation is implemented and specified in [Configurable Bar](configurable-bar.md). It validates global defaults and sparse exact-name per-monitor overrides, and `Bar.qml` applies the resolved position while preserving the top/island baseline. Top and bottom physical positioning remain the baseline; bottom visible masks and wraps mirror top around a centered vertical transform, native blur follows the bottom edge geometry, and the `CenterPanel` cutout follows bottom centerY. Left physical placement is implemented by reusing the horizontal top island source and applying a 90-degree counter-clockwise rotation to visible notch masks, decorative wraps, and bounded native blur Regions; content remains upright and stacked vertically, with left-side overlay offsets. The vertical owning `PanelWindow` spans the full output width so in-surface overlays such as `RightControlCenter` are not clipped; rendered islands remain edge-pinned and `exclusiveZone` remains the collapsed interactive width. Endpoint order and content modes are configurable independently from the fixed center/dashboard island. The service/power divider supports inward-facing `arc`, straight `hairline`, and `none` modes. `disabled` visibility filtering and removal of the Bar-owned surface set are implemented. Edge reveal remains always-visible; continuous rendering and detached dashboard attachment remain inert. Manual pointer-level dashboard/input verification is still pending; this spec makes no native-review approval claim. Future style configuration is intentionally inert. This spec remains the source of truth for the implemented bar.

## Behavior

### Configuration foundation

`Theme.qml` resolves one normalized configuration per exact `ShellScreen.name`, including bar position/visibility/style/reveal policy and dashboard attachment. Legacy `bar.screens` and `bar.style` remain compatible. Legacy `bar.screens` selection and its empty-match fallback run first; normalized per-monitor visibility then filters Bar instances. Thus explicit `visibility: "disabled"` may legitimately leave zero Bars and is not revived by fallback. `Bar.qml` consumes the resolved position for anchors, horizontal/vertical composition, masks, wraps, input regions, and `exclusiveZone`. `edge-reveal` remains current always-visible behavior; continuous style and detached dashboard attachment remain inert. Invalid values safely use defaults, unknown monitor names are inert, and a successful reload replaces the snapshot so removed overrides inherit again; malformed JSON preserves the last good snapshot.

### One instance per screen

- `Bar.qml` is a `PanelWindow` instantiated through `Variants` in `shell.qml`, one per enabled screen, with `screen: modelData` and `screenName: modelData.name`. It never assumes a monitor count or ordering — see `specs/multi-monitor.md`.
- Injected by the shell root: `screenName`, `hyprlandMonitor`, `notificationsState`, `systemStatsState`, `workspaceMonitorTick`. The instance never probes the compositor or creates its own pollers.
- Signals are connected per delegate instance in `shell.qml`, so every request carries its own screen identity. Bar instances never talk to each other.
- The overlays it owns — `PowerMenu`, `MprisPopup`, `CenterPanel`, `MetricsDropdown`, `RightControlCenter` — each receive `screenTarget: root.screen` and bind it to their inner `PanelWindow` as `screen: root.screenTarget`. Nesting alone is not enough: an unpinned layer-shell surface hands the compositor a null `wl_output` and lets it pick the output. See the "Screen targeting is explicit" section of `specs/multi-monitor.md`.
- If filtering removes this Bar, its currently Bar-owned surfaces disappear with it. `shell.qml` also clears active or pending Bar-owned overlay state by exact screen name, including pending opens on the shared timer. Launcher and wallpaper remain standalone; detached dashboards and other independent surfaces are future work.

### Layout
- Anchored to the configured edge: top/bottom span the output width; left/right remain edge-pinned inside full-output vertical `PanelWindow` surfaces while spanning the output height.
- Top/bottom compose islands horizontally; bottom mirrors the top visible silhouette around a centered vertical transform. Left reuses the horizontal top island source with a 90-degree counter-clockwise rotation for visible notch masks, decorative wraps, and bounded native blur Regions; content remains upright and stacked vertically, with the logical endpoint order resolved independently from the fixed center/dashboard island. Left swaps only the lateral geometry roles so each endpoint preserves the opposite top-bar silhouette, retaining outward-facing physical-right cap handedness. Right uses an explicit mirrored vertical frame for the body, caps, wraps, input region, and bounded native blur, and mirrors the divider toward the monitor interior.
- Contains three visible islands: logical start endpoint, center (clock + optional MPRIS chip when collapsed, dashboard body when expanded), and logical end endpoint; the endpoint order is resolved per monitor while the center remains fixed
- Reserves only the interactive content height on a horizontal edge, or interactive content width on a vertical edge, through `exclusiveZone`; the vertical surface width is independent so the in-surface RCC body and backdrop have room to render.
- Decorative wrapped silhouette depth follows the configured edge: below top, above bottom, and inward from either vertical edge when `Theme.barStyle === "silhouette"`.
- Keeps `PanelWindow.implicitHeight` stable at the expanded-aware surface height so opening the center dashboard does not resize the layer-shell surface or shift tiled windows
- `reservedBarContentHeight` is the max of the three sections' reserved heights and is the single value the bar hands the compositor as its horizontal exclusive zone (`Math.ceil` of it); vertical bars use the corresponding `reservedBarContentWidth`. Other components use the reserved dimension as the bar's hit band rather than guessing from `Theme.barHeight` or `Theme.barRailHeight`.
- Left and right islands share `sideTabHeight`; workspace chips and the four right-island service chips share `Theme.barChipHeight`; the power pill is the same height with a pill radius
- The center island uses `Theme.centerCollapsedWidth` when collapsed and `Theme.centerExpandedWidth` / `Theme.centerExpandedHeight` when expanded
- Expanded center content remains mounted in place without increasing reserved Hyprland space; the bar and `CenterPanel` explicitly request `WlrLayer.Top`. Static geometry and reload checks cover the reservation/catcher contract, while live pointer behavior and compositor stacking remain a manual verification boundary.
- The expanded dashboard body uses dashboard structural tokens for radius, background opacity, border width, and inner padding

### Motion
- `bar.motion` is resolved per monitor alongside position, order, content, and divider policy.
- `calm` is the default: center expansion and media width use `Motion.Spatial`; active workspace fills, service-chip state fills, and `StateLayer` opacity use `Motion.Effects`/`Motion.EffectsColor`.
- `reduced` disables only these bar-local behaviors; it does not alter geometry, input, routing, or unrelated shell animations. `expressive` currently aliases the shared Calm intents.

### Silhouette mask
- `Bar.qml` coordinates three independent `BarSection` surfaces rather than one shared silhouette surface
- `BarSection` and `NotchIslandMask` provide the selected-edge geometry. Bottom reuses the top mask and wrap primitives through a centered vertical mirror, and the native-blur region is edge-aware. Left reuses one canonical horizontal top-island source, centers it before the 90-degree counter-clockwise mapping `(u,v) -> (v,W-u)`, and uses the same body/cap/wrap geometry for debug and production masks; endpoint cap handedness and wrap gates are shared with the native-blur composition by `sectionId`; content remains upright and stacked vertically. Right uses the corrected mirrored vertical frame so visible mask, wraps, input union, and bounded native blur share one edge-specific contract.
- Each `BarSection` owns a hidden fill surface clipped through a `MultiEffect` mask
- The `PanelWindow` input mask is the union of the left, center, and right section hit regions, so transparent gaps remain click-through
- `NotchIslandMask` defines each island region with gap-facing top corner pieces
- `NotchCornerMask` draws explicit curved mask pieces, including lateral downward wrap pieces
- `Theme.barCurveRadius` controls shared corner curvature
- `Theme.barWrapDepth` controls decorative downward wrap depth independently from the curvature radius
- `Theme.debugBarSilhouette` can switch each section silhouette fill to high-contrast red for tuning

### Overlay coordination
- Exposes `closePowerMenu()`, `openPowerMenu()`, `closeMpris()`, `openMpris()`, `setMprisAnchor()`, `openMetrics()`, `closeMetrics()`, `openCenterPanel()`, `closeCenterPanel()`, `openRightControlCenter()`, `openRightControlCenterSection(section)`, and `closeRightControlCenter()` functions
- Exposes `powerMenuVisible`, `mprisVisible`, `centerPanelVisible`, the MPRIS anchor state (`mprisChipGlobalX`, `mprisChipWidth`, `mprisChipActive`), and power-button anchor properties as readonly state
- `mprisChipGlobalX` is the media chip's real center in window coordinates (`mprisChip.mapToItem(null, 0, 0).x + mprisChip.width / 2`), read by `openMpris()`, `setMprisAnchor()`, and the launcher band so anchor and hit region cannot diverge; it falls back to the center-tab midpoint while the chip geometry is degenerate. Geometry and verification: `specs/mpris.md`
- Does not communicate directly with launcher — routes through `shell.qml`
- `CenterPanel.qml` is an invisible `WlrLayer.Top` input catcher only — the same layer as the interactive panels, since `Overlay` is reserved for transient system feedback; it provides Escape/outside-click dismissal and leaves an input pass-through hole over the expanded center notch
- Managed-overlay semantics, reachability per name, and the single-slot (no context groups) model are specified in `specs/overlay-manager.md`

### Power button
- Distinct from the service chips by shape and color, not by an outline: a pill (`radius = height / 2`) with a resting red tint at `Theme.islandPowerTintOpacity` and a red `StateLayer` hover/press overlay — the destructive session action should not read as another service tile
- Positioned at right edge with fixed `x` exposed as `powerBtnGlobalX` for launcher click detection
- Click toggles PowerMenu overlay; popup behavior is unchanged by the right-island visual pass
- `PowerMenu` emits `opened()` / `closed()`; `Bar` re-emits as `powerMenuOpened` / `powerMenuClosed` and the shell updates `activeOverlay`. The signal pair was previously `onOpened()` / `closed()`, and `Bar` bound `onOnClosed:` to a signal that did not exist — closing the menu therefore never cleared overlay state. See `specs/overlay-manager.md`.

### Left island — workspaces
- `Workspaces.qml` renders a **per-monitor** view of the global `Hyprland.workspaces` model, filtered by monitor-name identity, with active state read from its own monitor's `activeWorkspace` rather than `Hyprland.focusedMonitor`. Full behavior in `specs/workspaces.md` and `specs/multi-monitor.md`.

### Center island
- Shows `ClockChip` by default
- Shows `MprisIndicator` when an MPRIS player has title or artist metadata
- The collapsed header is a `RowLayout` of `[filler, ClockChip, MprisIndicator, filler]` with `Theme.spacingSm` between items; the two equal `Layout.fillWidth` fillers center the clock+chip **group**, which puts the media chip's center `(clockWidth + spacing) / 2` right of the island's midpoint, independently of the chip's own width. Full derivation in `specs/mpris.md`
- Clicking the center island requests the in-place center dashboard toggle through `shell.qml`
- Expanded state hides the compact clock/media header so the dashboard owns the center notch surface
- Expanded state keeps the same center island visible and grows it in place rather than opening a separate visible floating panel
- Expanded state mounts `CenterDashboard.qml` inside the notch body with a vertical rail and tabbed content area
- The rail exposes `Media` and `Metrics` entries; clicking an entry switches the visible pane in place
- The rail uses dashboard tokens for rail width, tab height, and tab spacing
- The `Media` pane preserves the existing MPRIS behavior: title, artist, progress, previous/play-next controls, and `No media playing` fallback when no player is available
- The `Metrics` pane renders live visual telemetry from `SystemStats`: CPU/RAM/GPU cards with progress bars, Canvas sparklines, and percent values
- Metrics cards, card gaps, progress bar dimensions, sparkline dimensions, and footer height are bound to dashboard structural tokens
- GPU unavailable state displays a disabled `N/A` card instead of showing a fake `0%`
- The `Metrics` pane footer is a single compact row with `DSK | NET | VOL` values for disk throughput, network state, and volume/mute state
- Compact MPRIS chip clicks select the dashboard Media tab and open the in-place center dashboard through existing overlay coordination; they do **not** open the standalone `MprisPopup`
- The standalone `MprisPopup` is reachable only through launcher outside-click routing — see `specs/overlay-manager.md`

### Right island
- Four `RightIslandIconButton` **service chips** in order — Wi-Fi, Bluetooth, Audio, Notifications — then a configurable **semantic divider**, then the `PowerMenu` **pill**. The divider and the power pill are separate objects, not a fifth chip
- Each chip is a reusable button that **deep-links** into the control center: it emits `rightControlCenterSectionRequested("<section>")`, which opens `RightControlCenter` on that section rather than routing through an aggregate panel
- **State grammar (Caelestia-inspired adaptation — fill/shape/state-layer, no copied code, no hover-open, Tokyo City palette preserved):** chips express state through fill tint, icon accent, and the shared `StateLayer.qml` hover/press overlay — never through a per-chip border, because the wrapped silhouette already carries the edge. States, in precedence order:
  - `disabled` (adapter off) — quiet dimmed `base01` fill, muted icon; takes visual precedence over `active` so a powered-off radio never reads live
  - off / not connected — quiet `base01` fill at `Theme.opacityOverlay`, dim icon
  - `active` — accent-tinted fill at `Theme.islandActiveFillOpacity` + accent icon
  - `warning` (muted, DND) — orange-tinted fill + orange icon; warning wins over active
  - hover / press — `StateLayer` fill at `Theme.islandStateLayerHoverOpacity` / `Theme.islandStateLayerPressedOpacity`, inheriting the chip radius
- Chip fill animates state flips through `Motion.EffectsColor` (state can change while on screen; an instant color flip reads as a glitch). The hover-driven icon color is deliberately **not** animated — delaying pointer feedback would make the chip feel laggy
- `disabled` and `active` are fed from the injected `notificationsState` and the `pragma Singleton` services (`WifiService`, `BluetoothService`, `AudioService`) directly in `Bar.qml`; per-chip semantics: Wi-Fi disabled when the radio is off, active when enabled with an active SSID; Bluetooth likewise with connected devices; Audio active unless output-muted (muted shows warning); Notifications active when the retained store is non-empty, warning when DND or sound-muted
- The **semantic divider** between the service group and the power action is a decorative hairline colored from `Colors.muted` at `Theme.opacityBorder`. It takes no input and changes no routing. `Theme.islandSeparatorWidth` sets its width and `Theme.islandSemanticGap` adds whitespace on each side; setting the width to `0` removes **both** the line and the gap
- Click routing is unchanged by the visual pass; the consumer owns semantics via `clicked`
- Section semantics, card content, and layout of the control center are specified in `specs/right-island-control-center.md`; the motion primitive in `specs/theme-system.md`
- **Verification status:** implemented; Qt 6.11 lint-clean and validated by offscreen motion probes. Live compositor visual confirmation and a debug-off screenshot are still pending — see `odd/tasks/caelestia-right-island.md`

### Metrics entry point — deliberately absent
- **Decision:** the right island has no metrics button. `MetricsButton.qml` is deleted and its `bar/qmldir` entry removed, along with the never-emitted `Bar.metricsToggleRequested` and `Bar.mprisToggleRequested` signals and their `shell.qml` handlers.
- Telemetry lives in two live surfaces: the center dashboard `Metrics` pane and `MetricsControlCard.qml` in the control center. A third compact dropdown in the right island would be redundant.
- `MetricsDropdown.qml` remains on disk, instantiated per bar, screen-pinned, and fed `systemStatsState`, as **dormant infrastructure, not an oversight**: its wiring is intact so a future explicit trigger is one signal, not a rebuild. It currently has no way to be opened. Details in `specs/overlay-manager.md`.

## Verification boundary

The implementation boundary above describes the current QML source. Top, bottom, left, and right geometry contracts are implemented; static and reload checks cover the corrected lateral frames and collapsed reservation. Pointer-level dashboard interaction and live compositor stacking remain unverified, and this document makes no native-review or compositor-approval claim.
