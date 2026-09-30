# Launcher

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/launcher/LauncherCentered.qml`, coordination in `quickshell/.config/quickshell/shell.qml`

## Description
Keyboard-driven app launcher. A single fullscreen `PanelWindow` with one centered popup that filters the desktop-entry model and launches an entry. Coordination (open, close, exclusivity) lives in `shell.qml`; the launcher itself only renders and emits dismissal signals.

## Behavior

### Surface
- `PanelWindow` with `WlrLayershell.layer: WlrLayer.Top`, `exclusionMode: ExclusionMode.Ignore`, and all four anchors set — the surface spans the whole of its pinned screen when visible (see "Screen placement"). `Top`, not `Overlay`: the Overlay layer is reserved for transient system feedback, see `specs/overlay-manager.md`
- **The bar renders above this surface.** Both live in `Top`, and Hyprland stacks the bar on top: measured by capturing the bar band with the launcher closed and open (`grim`, 900x42 px at the bar's position) — 0.0 % of pixels changed and mean brightness identical, while the desktop region behind it visibly dimmed. So the launcher's backdrop does not darken the bar, unlike the earlier Overlay-layer behavior.
- Input follows the same order: the bar declares an input `mask` over its island hit regions, so a click landing on a chip reaches the chip directly even while the launcher is open, and the launcher stays exclusive because the chip's own request runs through `overlayManager.open()`. The launcher receives only clicks in the transparent gaps between islands, which is where its bar-band heuristic applies.
- `visible: false` by default; the surface is mapped only while the overlay is open
- Transparent window color; the only visible content is one centered popup card
- Popup size is fixed by local constants `popupW: 560` / `popupH: 480` — **divergence:** these are not `Theme` tokens, so the launcher is the bar-family exception to the configurability-first rule
- Horizontal placement: `anchors.horizontalCenter` of the full-screen surface
- Vertical placement: `anchors.topMargin = Math.round((parent.height - Theme.barHeight - popupH) / 2 + Theme.barHeight)` — optically centered in the area below the reserved bar height, not geometrically centered on the screen

### Screen placement
- Exactly one launcher instance exists, declared in `shell.qml` (`LauncherCentered { id: launcher }`)
- The surface pins itself to the focused monitor: `property ShellScreen targetScreen: null` with `screen: root.targetScreen`, written by `resolveTargetScreen()`, which matches `Hyprland.focusedMonitor.name` against `ShellScreen.name` over `Quickshell.screens` — never by list index, never assuming a monitor count
- The write is imperative and happens **only while the surface is unmapped**: `toggleOpen()` calls `resolveTargetScreen()` in the show branch before `visible = true`, because `ProxyWindowBase::setScreen()` unmaps and re-maps a surface whose output changes while it is mapped
- Unresolvable focus (no focused monitor yet, or a hot-plug race with no `ShellScreen` for it) leaves the previous pin untouched, so the surface can neither throw nor vanish
- Matches `specs/multi-monitor.md` ("Launcher | focused screen"). Observed live: focused `DP-1` filled the overlay `1920 0 2560 1440`; focused `DP-2` filled `0 320 1920 1080`

### Opening and closing
- Open path: `overlayManager.open("", "launcher")` from the `launcher` IPC handler → 50 ms timer → `launcher.toggleOpen()`
- `toggleOpen()` calls `resolveTargetScreen()`, then resets `mode = "search"`, `filterText = ""`, `selectedRow = 0` before showing; a closed launcher always reopens as a fresh search
- `visible = false` set by `overlayManager._closeActive()` does **not** emit `dismissed()` — the coordinator closes the surface directly and keeps its own state
- `dismissed()` is emitted only from the launcher itself (outside click, `Escape` in navigate mode, after a launch); `shell.qml` maps it to `overlayManager.close("", "launcher")`

### Keyboard focus
- `WlrKeyboardFocus.OnDemand` while visible, `WlrKeyboardFocus.None` while hidden
- `onVisibleChanged` calls `keyHandler.forceActiveFocus()` when shown
- `keyHandler` is a focus-holding `Item` filling the popup card; all key handling is in its `Keys.onPressed`

### Two input modes
- `mode: "search"` (default on open): printable unmodified characters append to `filterText`, `Backspace` trims it, `Up`/`Down` move the selection, `Return`/`Enter` launches, `Escape` switches to `"navigate"` instead of closing
- `mode: "navigate"`: `j`/`k` and `Up`/`Down` move the selection, `Return`/`Enter` launches, `i` returns to `"search"`, `Escape` closes the launcher and emits `dismissed()`
- There is no `TextInput`: the search row is a `Text` bound to `filterText`, so there is no caret, selection, clipboard paste, or IME composition
- Placeholder text is `"Buscar apps..."` in search mode and `"Pulsa 'i' para buscar"` in navigate mode; the bottom hint line lists the mode's own key set

### App model and filtering
- Source is the Quickshell `DesktopEntries.applications` model; entries are read by index and launched with `entry.execute()`
- The filtered `ListModel` is rebuilt on `Component.onCompleted`, on every `filterText` change, and on `DesktopEntries.applicationsChanged`
- Match rule: case-insensitive substring of `entry.name` only — `comment` is displayed but never searched
- Each filtered row stores the original `entryIndex`, so launching and hover-selection address the unfiltered model
- Empty filter shows every entry; a non-matching filter shows an empty list, and both `moveSelection()` and `launchSelected()` no-op when `count === 0`
- After a rebuild, `selectedRow >= count` resets the selection to `0`
- Selection wraps: `selectedRow = (selectedRow + delta + count) % count`, and the `ListView` calls `positionViewAtIndex(selectedRow, ListView.Contain)`
- Delegate hover sets `selectedRow`; delegate click launches immediately. Hover changes selection only — it never opens or closes the overlay

### Outside-click routing
- A full-screen `MouseArea` is declared before the popup card, so the card sits above it in z-order
- Clicking that area hides the launcher, emits `dismissed()`, then emits `outsideClicked(x, y)` with the click position
- The popup card installs a click-consuming `MouseArea`; list delegates consume their own clicks, so neither reaches the dismiss area
- `shell.qml` interprets `outsideClicked`: `inBar = y < bar.reservedBarContentHeight`, then `x >= bar.powerBtnGlobalX` opens `"powermenu"`, otherwise a hit on the MPRIS chip band (`bar.mprisChipActive` and `x` within `mprisChipGlobalX ± mprisChipWidth / 2`) calls `bar.setMprisAnchor()` and opens `"mpris"`
- `reservedBarContentHeight` is the bar's interactive height — observed at `42` px on both monitors, the same value the bar hands Hyprland as its exclusive zone (`reserved: 0 42 0 0`). The earlier test compared `y` with `Theme.barRailHeight`, a 4 px decorative rail, so it could never be true over chips that are `Theme.barChipHeight` (30) tall and every bar click simply closed the launcher. With the threshold fixed, both chained opens are reachable
- Bar geometry is read from the instance resolved by `barForScreen()` for the launcher's own screen — `barForScreen(launcher.targetScreen === null ? "" : launcher.targetScreen.name)`, so a null target falls back to the documented no-screen-intent path (first instance)
- The screen pin is what makes the `x` test meaningful: `outsideClicked` reports coordinates inside the launcher's own surface, while `powerBtnGlobalX` / `mprisChipGlobalX` are relative to the bar surface, and those two frames only agree on the same monitor
- **MPRIS band precision:** `mprisChipGlobalX` is the media chip's real center — `mprisChip.mapToItem(null, 0, 0).x + mprisChip.width / 2`, with `mprisChip.x` read so the binding re-evaluates when the header fillers re-center the clock/chip pair — and falls back to the center-tab midpoint only when the chip geometry is degenerate. The band and the popup anchor read that same property, so they cannot drift apart. Measured live, the chip center sits `49` px right of the tab midpoint (`(clockWidth + spacing) / 2`, independent of the chip's own width); before that read existed, the band was offset left by that amount and only the chip's left part was clickable. See the geometry section and the open decision recorded in `specs/mpris.md`

### Token usage
- Layout/shape: `Theme.barHeight`, `Theme.radiusLg`, `Theme.radiusSm`, `Theme.spacingLg`, `Theme.spacingMd`, `Theme.spacingSm`, `Theme.opacitySurface`, `Theme.opacityBorder`
- Type: `Colors.uiFont` for app names and comments, `Colors.monoFont` for the search icon and the hint line
- Color: `Colors.base01` card, `Colors.surface` search field, `Colors.accent` selection and search-mode border, `Colors.text` / `Colors.textDim` / `Colors.muted` for text
