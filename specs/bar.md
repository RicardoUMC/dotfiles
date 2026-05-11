# Bar

**Status:** Implemented
**File:** `quickshell/.config/quickshell/bar/Bar.qml`

## Description
Top-anchored floating bar composed of independent islands. Coordinates overlay state for all bar-level components.

## Behavior

### Layout
- Anchored to top of screen, full width
- Contains three zones: left (workspaces), center (fill), right (MPRIS chip, system stats, power button)
- Height: 37px

### Overlay coordination
- Exposes `closePowerMenu()`, `openPowerMenu()`, `closeMpris()` functions
- Exposes `powerMenuVisible` and `mprisVisible` readonly properties
- Does not communicate directly with launcher — routes through `shell.qml`

### Power button
- Positioned at right edge with fixed `x` exposed as `powerBtnGlobalX` for launcher click detection
- Click toggles PowerMenu overlay

## Planned changes
- Refactor into floating islands (separate segments with gaps) per DESIGN.md
- Islands: workspaces island (left), stats island (right), power island (far right)
