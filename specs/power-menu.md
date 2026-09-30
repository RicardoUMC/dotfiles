# Power Menu

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/bar/PowerMenu.qml`, `PowerMenuItem.qml`, hosted in `bar/Bar.qml`, coordination in `shell.qml`

## Description
Power and session overlay with three actions. The trigger chip lives inside the bar's right tab; the menu itself is a nested fullscreen `PanelWindow` that manages its own backdrop and dismissal, and reports open/closed transitions up to `shell.qml` through `Bar.qml`.

## Behavior

### Entry points
- Chip click on the bar's power button (`onClicked: popup.visible ? root.close() : root.open()`)
- `quickshell ipc call powermenu toggle`, wired to `$mainMod, X` in `hyprland/.config/hypr/hyprland.conf`, handled by the `powermenu` `IpcHandler` in `shell.qml` → `overlayManager.open("", "powermenu")`
- Outside-click routing from the launcher (`shell.qml`): a launcher dismiss click with `x >= bar.powerBtnGlobalX` opens `"powermenu"`. That heuristic is gated by `y < bar.reservedBarContentHeight` — the bar's interactive height, observed at `42` px — so clicks on the power chip through an open launcher do chain into the menu. See `specs/launcher.md`
- `overlayManager.open()` is a toggle: opening `"powermenu"` while it is the active overlay on the same screen closes it instead

### Trigger chip
- `28` px wide, `Theme.barChipHeight` tall, radius `Theme.radiusSm`
- Glyph `⏻` in `Colors.monoFont` at `Theme.fontSizeBody`
- Idle: `Colors.base01` fill at `Theme.opacityOverlay`, `Colors.muted` text and `Theme.opacityBorder` border
- Hover: `Colors.red` fill at `Theme.opacityDim`, `Colors.red` text and a `0.5`-alpha red border
- The chip is an `Item` whose `implicitWidth`/`implicitHeight` mirror the button, so `Bar.qml` can compute `powerBtnGlobalX = rightTab.x + rightTab.width - powerMenu.implicitWidth - Theme.tabPaddingH`

### Surface
- Outer `Item` is the chip; the menu itself is a nested `PanelWindow` (`visible: false` by default) with `WlrLayershell.layer: WlrLayer.Top`, `exclusionMode: ExclusionMode.Ignore`, transparent color, and all four anchors set — a full-screen backdrop per screen. `Top`, not `Overlay`: the Overlay layer is reserved for transient system feedback, see `specs/overlay-manager.md`
- `property var screenTarget: null` is forwarded to the popup as `screen: root.screenTarget`, and `Bar.qml` binds `screenTarget: root.screen`. The code comment records the reason: "an unpinned layer-shell surface lets the compositor choose the output" — pinning is explicit, not a consequence of nesting
- `WlrLayershell.keyboardFocus: visible ? OnDemand : None`, and `onVisibleChanged: if (visible) keyHandler.forceActiveFocus()`
- No `exclusiveZone`: the menu overlays app content without changing reserved bar space

### Anchor geometry
- Menu card is anchored `top` + `right` of the fullscreen popup with `topMargin: Theme.barHeight + Theme.spacingMd - 1` and `rightMargin: Theme.spacingMd - 1` — identical placement to the notification surface, so both hang under the right island
- Card width is a literal `160`; height is `col.implicitHeight + Theme.spacingLg`
- Card fill `Colors.base01` at `Theme.opacitySurface`, radius `Theme.radiusMd`, 1 px border of `Colors.muted` at `0.35` alpha
- Inner `ColumnLayout` uses `margins: Theme.spacingSm`, `spacing: Theme.spacingXs`

### Actions offered
| Index | Icon | Label | Command | Danger |
|-------|------|-------|---------|--------|
| 0 | `󰜉` | `Reiniciar` | `systemctl reboot` | no |
| 1 | `󰐥` | `Apagar` | `systemctl poweroff` | yes |
| 2 | `󰍃` | `Cerrar sesión` | `hyprctl dispatch exit` | no |

- `popup.itemCount` is a read-only `3`, matching the `actions` array and the three `PowerMenuItem` delegates
- A non-selectable 1 px separator `Rectangle` (`Colors.muted` at `0.2`) sits between the Apagar and Cerrar sesión rows; it is decoration only and is not counted in `itemCount`
- Every action hides the popup first, then starts its `Process`; the popup is closed even if the command fails
- `PowerMenu.qml` holds three independent `Process` nodes (`rebootCmd`, `poweroffCmd`, `logoutCmd`) — no confirmation step is required before any of them runs
- **Known gap:** the action paths — both `keyHandler.actions` and the `PowerMenuItem.onActivated` handlers — set `popup.visible = false` directly instead of calling `root.close()`, so they do **not** emit `closed()`. Activation during a session change is invisible to the coordinator; `specs/overlay-manager.md`'s "every close path emits `closed()`" describes the click/Escape/`close()` paths, not these

### Item rendering (`PowerMenuItem.qml`)
- `Layout.fillWidth`, `implicitHeight: 34`, radius `Theme.radiusSm`
- Highlight fill when hovered or `selected`: `Colors.red` at `0.18` when `danger`, otherwise `Colors.accent` at `0.12`; transparent otherwise
- Icon uses `Colors.monoFont` at `Theme.fontSizeBodyLg`; danger items are always `Colors.red`, normal items `Colors.muted`
- Label uses `Colors.uiFont` at a literal `pixelSize: 12`; active text is `Colors.text` (or `Colors.red` when dangerous), idle text is `Colors.textDim`
- Clicking emits `activated()`, which the popup binds to the same action as the keyboard path

### Keyboard navigation
- `keyHandler` is a focus-holding `Item` filling the popup
- `j` / `Down` → `selectedIndex = (selectedIndex + 1) % itemCount`
- `k` / `Up` → `selectedIndex = (selectedIndex - 1 + itemCount) % itemCount` (wraps in both directions)
- `Return` / `Enter` → `actions[popup.selectedIndex]()`
- `Escape` → hide the popup and emit `root.closed()`
- `open()` resets `popup.selectedIndex = 0`, so every open starts on Reiniciar
- There is no mouse-independent focus ring; the visual `selected` state is bound to `popup.selectedIndex === n`

### Dismissal
- Click outside: a full-popup `MouseArea` covers the surface and closes the menu (`popup.visible = false; root.closed()`); the card installs its own click-consuming `MouseArea` so its clicks never reach the backdrop
- `Escape` as above
- Activating an action does **not** dismiss through this path: it hides the popup without emitting `closed()` — see the known gap under "Actions offered"
- Workspace / window events: `shell.qml` calls `overlayManager.closeAll()` on Hyprland `workspace`, `workspacev2`, `moveworkspace`, `movewindow`, `activewindow`, and `fullscreen` events, which routes through `bar.closePowerMenu()`
- Opening another overlay closes it first via `overlayManager._closeActive()`
- The menu does not close on a timeout and has no auto-dismiss timer

### Overlay coordination and state ownership
- `PowerMenu` owns its visibility: `readonly property bool isOpen: popup.visible`
- Signals: `opened()` fires from `open()`, `closed()` fires from `close()`, the backdrop click, and `Escape`. They were previously `onOpened()` / `closed()`, and `Bar.qml` bound `onOnClosed:` to a signal that did not exist — closing the menu therefore silently never reached the manager and `activeOverlay` stayed set to `"powermenu"` after the surface was gone. The rename fixed that state leak
- `Bar.qml` re-emits them as `powerMenuOpened()` / `powerMenuClosed()` and exposes `closePowerMenu()` / `openPowerMenu()` plus `powerMenuVisible`
- `shell.qml` connects `onPowerMenuClosed` per bar instance → `overlayManager.close(barInstance.screenName, "powermenu")`; opens are requested through `overlayManager.open(...)` → `bar.openPowerMenu()` after the shared 50 ms timer
- The coordinator — not the menu — is the single place where overlay exclusivity is decided; `PowerMenu.qml` never talks to the launcher or any other overlay
- `_closeActive()` resolves the owning `Bar` instance through `barForScreen(activeScreenName)` and skips the command when that instance no longer exists (unplugged monitor), clearing state only
- Exclusivity is one global slot keyed by `activeOverlay` + `activeScreenName`, with no context groups — see `specs/overlay-manager.md`
- IPC and keybind opens pass an empty screen identity, so they resolve through `barForScreen("")`'s first-instance fallback rather than the focused screen. Observed: with `DP-2` focused, `quickshell ipc call powermenu toggle` opened the menu on `DP-1`. Documented limitation tracked in `specs/multi-monitor.md`

### Debug scaffolding
- Both the card and each `PowerMenuItem` draw a debug border `Rectangle` at `z: 999`, visible only when `Theme.debugVisualBounds` is true, using `Theme.debugBorderColor` and `Theme.debugBorderWidth`

### Token usage
- `Theme.barChipHeight`, `Theme.barHeight`, `Theme.radiusSm`, `Theme.radiusMd`, `Theme.spacingLg`, `Theme.spacingMd`, `Theme.spacingSm`, `Theme.spacingXs`, `Theme.tabPaddingH`, `Theme.opacitySurface`, `Theme.opacityOverlay`, `Theme.opacityBorder`, `Theme.opacityDim`, `Theme.fontSizeBody`, `Theme.fontSizeBodyLg`
- Colors: `Colors.red` for the danger path and hover, `Colors.accent` for selection, `Colors.base01` for surfaces, `Colors.muted` / `Colors.text` / `Colors.textDim` for text
- Fonts: `Colors.monoFont` for icons and the power glyph, `Colors.uiFont` for labels
- Hardcoded literals that are not yet tokens: chip width `28`, card width `160`, item height `34`, item font `pixelSize: 12`, border width `1`, and the various `0.18` / `0.12` / `0.35` / `0.5` / `0.2` alpha values
