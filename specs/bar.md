# Bar

**Status:** Implemented
**File:** `quickshell/.config/quickshell/bar/Bar.qml`

## Description
Top-anchored floating bar composed of independent wrapped-silhouette islands. Coordinates overlay state for all bar-level components and expands the center island in place into a lightweight dashboard.

## Behavior

### Layout
- Anchored to top of screen, full width
- Contains three visible islands: left (workspaces), center (clock + optional MPRIS chip), right (metrics button + power button)
- Reserves only the interactive content height through `exclusiveZone`
- Decorative wrapped silhouette depth may draw below the reserved height when `Theme.barStyle === "silhouette"`
- Left and right islands share `sideTabHeight`; workspace, metrics, and power chips share `Theme.barChipHeight`
- The center island uses `Theme.centerCollapsedWidth` when collapsed and `Theme.centerExpandedWidth` / `Theme.centerExpandedHeight` when expanded
- Expanded center content overlays app windows without increasing reserved Hyprland space
- The expanded dashboard body uses dashboard structural tokens for radius, background opacity, border width, and inner padding

### Silhouette mask
- Uses one hidden fill surface clipped through a `MultiEffect` mask
- `NotchIslandMask` defines separated island regions with gap-facing top corner pieces
- `NotchCornerMask` draws explicit curved mask pieces, including lateral downward wrap pieces
- `Theme.barCurveRadius` controls shared corner curvature
- `Theme.barWrapDepth` controls decorative downward wrap depth independently from the curvature radius
- `Theme.debugBarSilhouette` can switch the silhouette fill to high-contrast red for tuning

### Overlay coordination
- Exposes `closePowerMenu()`, `openPowerMenu()`, `closeMpris()`, `openMpris()`, `openMetrics()`, `closeMetrics()`, `openCenterPanel()`, and `closeCenterPanel()` functions
- Exposes `powerMenuVisible`, `mprisVisible`, MPRIS anchor properties, and power-button anchor properties as readonly state
- Does not communicate directly with launcher — routes through `shell.qml`
- `CenterPanel.qml` is an invisible overlay-layer input catcher only; it provides Escape/outside-click dismissal and leaves an input pass-through hole over the expanded center notch

### Power button
- Positioned at right edge with fixed `x` exposed as `powerBtnGlobalX` for launcher click detection
- Click toggles PowerMenu overlay

### Center island
- Shows `ClockChip` by default
- Shows `MprisIndicator` when an MPRIS player has title or artist metadata
- Clicking the center island requests the in-place center dashboard toggle through `shell.qml`
- Expanded state keeps the same center island visible and grows it in place rather than opening a separate visible floating panel
- Expanded state mounts `CenterDashboard.qml` inside the notch body with a vertical rail and tabbed content area
- The rail exposes `Media` and `Metrics` entries; clicking an entry switches the visible pane in place
- The rail uses dashboard tokens for rail width, tab height, and tab spacing
- The `Media` pane preserves the existing MPRIS behavior: title, artist, progress, previous/play-next controls, and `No media playing` fallback when no player is available
- The `Metrics` pane renders live visual telemetry from `SystemStats`: CPU/RAM/GPU cards with progress bars, Canvas sparklines, and percent values
- Metrics cards, card gaps, progress bar dimensions, sparkline dimensions, and footer height are bound to dashboard structural tokens
- GPU unavailable state displays a disabled `N/A` card instead of showing a fake `0%`
- The `Metrics` pane footer is a single compact row with `DSK | NET | VOL` values for disk throughput, network state, and volume/mute state
- Compact MPRIS chip clicks open the existing `MprisPopup`; expanded MPRIS chip clicks do not open a separate popup because media controls live inside the notch

### Metrics button
- Compact icon button in the right island
- Click emits a metrics toggle request; overlay coordination stays outside the button
- The existing `MetricsDropdown.qml` remains the compact right-island metrics overlay and is separate from the center dashboard Metrics pane
