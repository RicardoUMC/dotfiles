# Bar

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/bar/Bar.qml`, `BarTab.qml`, `BarSection.qml`, `NotchIslandMask.qml`, `NotchCornerMask.qml`, `Workspaces.qml`, `RightIslandIconButton.qml`, `RightControlCenter.qml`, instantiation in `shell.qml`

## Description

Top-anchored floating bar composed of independent wrapped-silhouette islands. Each `Bar` is one instance bound to one screen; it coordinates the overlay state of the surfaces it owns and expands the center island in place into a lightweight dashboard.

## Behavior

### One instance per screen

- `Bar.qml` is a `PanelWindow` instantiated through `Variants` in `shell.qml`, one per enabled screen, with `screen: modelData` and `screenName: modelData.name`. It never assumes a monitor count or ordering — see `specs/multi-monitor.md`.
- Injected by the shell root: `screenName`, `hyprlandMonitor`, `notificationsState`, `systemStatsState`, `workspaceMonitorTick`. The instance never probes the compositor or creates its own pollers.
- Signals are connected per delegate instance in `shell.qml`, so every request carries its own screen identity. Bar instances never talk to each other.
- The overlays it owns — `PowerMenu`, `MprisPopup`, `CenterPanel`, `MetricsDropdown`, `RightControlCenter` — each receive `screenTarget: root.screen` and bind it to their inner `PanelWindow` as `screen: root.screenTarget`. Nesting alone is not enough: an unpinned layer-shell surface hands the compositor a null `wl_output` and lets it pick the output. See the "Screen targeting is explicit" section of `specs/multi-monitor.md`.

### Layout
- Anchored to top of screen, full width
- Contains three visible islands: left (workspaces), center (clock + optional MPRIS chip when collapsed, dashboard body when expanded), right (four control-center icons + power button)
- Reserves only the interactive content height through `exclusiveZone`
- Decorative wrapped silhouette depth may draw below the reserved height when `Theme.barStyle === "silhouette"`
- Keeps `PanelWindow.implicitHeight` stable at the expanded-aware surface height so opening the center dashboard does not resize the layer-shell surface or shift tiled windows
- `reservedBarContentHeight` is the max of the three sections' reserved heights and is the single value the bar hands the compositor as its exclusive zone (`Math.ceil` of it). Observed at `42` px on both monitors via `hyprctl monitors` (`reserved: 0 42 0 0`). Other components use it as the bar's hit band rather than guessing from `Theme.barHeight` or `Theme.barRailHeight`.
- Left and right islands share `sideTabHeight`; workspace, control-center, and power chips share `Theme.barChipHeight`
- The center island uses `Theme.centerCollapsedWidth` when collapsed and `Theme.centerExpandedWidth` / `Theme.centerExpandedHeight` when expanded
- Expanded center content overlays app windows without increasing reserved Hyprland space
- The expanded dashboard body uses dashboard structural tokens for radius, background opacity, border width, and inner padding

### Silhouette mask
- `Bar.qml` coordinates three independent `BarSection` surfaces rather than one shared silhouette surface
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
- Positioned at right edge with fixed `x` exposed as `powerBtnGlobalX` for launcher click detection
- Click toggles PowerMenu overlay
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
- Four `RightIslandIconButton` chips in order: Wi-Fi, Bluetooth, Audio, Notifications, followed by the `PowerMenu` button
- Each chip is a reusable icon + active/warning-accent button that **deep-links** into the control center: it emits `rightControlCenterSectionRequested("<section>")`, which opens `RightControlCenter` on that section rather than routing through an aggregate panel
- Chip state is read from the injected `notificationsState` and from the `pragma Singleton` services (`WifiService`, `BluetoothService`, `AudioService`) directly in `Bar.qml`
- Active/warning semantics per chip: Wi-Fi active when enabled with an active SSID; Bluetooth active when enabled with connected devices; Audio active unless output-muted (muted shows the warning tint); Notifications active when the retained store is non-empty, warning when DND or sound-muted
- Section semantics, card content, and layout of the control center are specified in `specs/right-island-control-center.md`

### Metrics entry point — deliberately absent
- **Decision:** the right island has no metrics button. `MetricsButton.qml` is deleted and its `bar/qmldir` entry removed, along with the never-emitted `Bar.metricsToggleRequested` and `Bar.mprisToggleRequested` signals and their `shell.qml` handlers.
- Telemetry lives in two live surfaces: the center dashboard `Metrics` pane and `MetricsControlCard.qml` in the control center. A third compact dropdown in the right island would be redundant.
- `MetricsDropdown.qml` remains on disk, instantiated per bar, screen-pinned, and fed `systemStatsState`, as **dormant infrastructure, not an oversight**: its wiring is intact so a future explicit trigger is one signal, not a rebuild. It currently has no way to be opened. Details in `specs/overlay-manager.md`.

## Verified at runtime

- Two bar surfaces on the live compositor, one per output, each sized to its own monitor: `1920 0 2560 272` (`DP-1`) and `0 320 1920 272` (`DP-2`), from a single `quickshell` process (`pid 400230`) — `hyprctl layers`.
- Exclusive zone `0 42 0 0` on both monitors — `hyprctl monitors`.
- The power-menu overlay opened as a full-`DP-1` surface (`1920 0 2560 1440`) while `DP-2` held focus — it did not follow focus, and it matched its owning bar's monitor. See `specs/multi-monitor.md` for why this supports, without by itself proving, the `screenTarget` pinning.
