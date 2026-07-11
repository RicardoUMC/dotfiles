# Bar

**Status:** Implemented
**File:** `quickshell/.config/quickshell/bar/Bar.qml`

## Description
Top-anchored floating bar composed of independent wrapped-silhouette islands. Coordinates overlay state for all bar-level components.

## Behavior

### Layout
- Anchored to top of screen, full width
- Contains three visible islands: left (workspaces), center (clock + optional MPRIS chip), right (metrics button + power button)
- Reserves only the interactive content height through `exclusiveZone`
- Decorative wrapped silhouette depth may draw below the reserved height when `Theme.barStyle === "silhouette"`
- Left and right islands share `sideTabHeight`; workspace, metrics, and power chips share `Theme.barChipHeight`

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

### Power button
- Positioned at right edge with fixed `x` exposed as `powerBtnGlobalX` for launcher click detection
- Click toggles PowerMenu overlay

### Center island
- Shows `ClockChip` by default
- Shows `MprisIndicator` when an MPRIS player has title or artist metadata
- Clicking the center island requests the floating center panel toggle through `shell.qml`

### Metrics button
- Compact icon button in the right island
- Click emits a metrics toggle request; overlay coordination stays outside the button
