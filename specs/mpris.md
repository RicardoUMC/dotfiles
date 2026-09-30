# MPRIS

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/bar/MprisIndicator.qml`, `CenterDashboard.qml`, `MprisPopup.qml`, routing in `bar/Bar.qml` and `shell.qml`

## Description
Music/media player integration via MPRIS D-Bus protocol. Composed of a bar chip, the center dashboard Media pane, and a standalone popup player that the launcher's bar band can open.

## Indicator Chip

### Visibility
- Visible only when a player exists AND has a non-empty `trackTitle` or `trackArtist` (`MprisIndicator.qml`: `active` gates `visible`)
- Hidden when no player is registered or the current player carries no title and no artist
- Width animates in/out (`Behavior on implicitWidth`, `Theme.animFast` — `180` in `config.json` — with `Easing.OutCubic`)

### Display
- Icon: `󰎆` (playing) or `󰎇` (paused/stopped) — Nerd Font, accent color
- Title: truncated to 28 characters with `…`
- Click: selects the center dashboard Media tab and opens the in-place center dashboard when clicked from the visible compact bar chip

### Player selection priority
1. First player with `playbackState === Playing`
2. Fallback: first available player
3. `null` when no player is registered

## Center Dashboard Media Pane

### Trigger
- Opens from visible compact center MPRIS chip clicks
- The chip click selects the Media tab before opening the in-place center dashboard
- The expanded center dashboard hides the compact clock/media header, so media controls live in the dashboard body rather than in an expanded chip target

### Controls behavior
- Previous: `mediaPlayer?.previous()`
- Play/Pause: `mediaPlayer?.togglePlaying()`
- Next: `mediaPlayer?.next()`
- Empty state: the title text falls back to `"No media playing"`, and the artist row, progress bar, and control row are hidden when `mediaPlayer` is `null` (`CenterDashboard.qml` `visible: root.mediaPlayer !== null`)
- The pane receives its player as the injected `mediaPlayer` property from `Bar.qml`, not by probing `Mpris.players` itself

## Popup Player

### Trigger — reachable today, through the launcher bar band
- The launcher's `outsideClicked` handler in `shell.qml` opens it: with the launcher open, a dismiss click inside the bar band (`y < bar.reservedBarContentHeight`, observed at `42` px) that lands within `bar.mprisChipGlobalX ± bar.mprisChipWidth / 2` while `bar.mprisChipActive` is true calls `bar.setMprisAnchor()` and `overlayManager.open(bar.screenName, "mpris")`
- The older claim that the popup "remains available for a future explicit trigger" is no longer true: it has a live trigger. `specs/overlay-manager.md` records the same emit site as the only one for the `mpris` name
- The band threshold fix is what restored this. While the test compared `y` with `Theme.barRailHeight` (4 px), the branch could never fire and the popup was unreachable in practice
- **The two entry points lead to different surfaces.** Clicking the compact media chip normally selects the dashboard `Media` tab and opens the in-place center dashboard (`center-panel`). Clicking the same chip while the launcher is open goes through the launcher routing and opens the standalone `MprisPopup`. Same chip, two surfaces, chosen by whether the launcher was up
- `Bar.openMpris()` and `Bar.setMprisAnchor()` both read the single `mprisChipGlobalX` property for the anchor
- Closes on click outside (full-surface `MouseArea` → `root.close()`, which emits `closed()`) and on a workspace/window event (`overlayManager.closeAll()` → `bar.closeMpris()`). It does **not** close on `Escape`: `MprisPopup.qml` declares no `keyboardFocus` and no key handler
- Exclusivity is the single global slot (`activeOverlay` + `activeScreenName`): opening it closes whatever was active, on any screen. There are no context groups — see `specs/overlay-manager.md`
- The surface pins to its bar's screen through `screenTarget: root.screen` → `screen: root.screenTarget`

### Geometry and anchor accuracy
- Card is `280` px wide, `320` px tall when `trackArtUrl` is non-empty and `220` px otherwise, at `y: 44`, with `x` clamped to `anchorX - popupW / 2` inside 8 px screen margins
- `anchorX` is the **media chip's real center**, not the center-tab midpoint: `mprisChipGlobalX = mprisChip.mapToItem(null, 0, 0).x + mprisChip.width / 2`. Because `mapToItem()` is a function call the binding engine cannot observe, the binding also reads `mprisChip.x`, which registers the dependency that re-evaluates the value when the fillers re-center the clock/chip pair; the same read is a monotonicity sanity check.
- Header geometry, for reference: the collapsed row is `[filler, ClockChip, MprisIndicator, filler]` with `RowLayout` spacing `s`, and the two equal fillers center the **pair**. With clock width `c` and chip width `w`, the chip's center sits right of the row midpoint by `(c + s + w) / 2 - w / 2`; the `w` term cancels:

  ```text
  chip center - row midpoint = (c + s) / 2
  ```

  The offset is therefore **independent of the media chip's own width**: it does not shrink, grow, or change sign as the song title gets longer.
- Measured in the running session: `c ≈ 88.5`, `s = Theme.spacingSm = 8`, giving `(88.5 + 8) / 2 ≈ 48.3` px, against an observed offset of `49` px — `RowLayout` rounds item geometry to integers.
- **Why the property exists.** While the anchor and the launcher band both used the tab midpoint, the band sat ~48 px left of the visible chip, so band and chip barely overlapped: only the chip's left part was clickable, a click on its right part closed the launcher instead of opening the popup, and the band's left edge reached into the right side of the clock chip.
- **What a longer title actually changes** is where the chip's left edge lands relative to a band center that had not moved — the band's half-width uses `mprisChipWidth`, which is content-driven. The error was one-sided (band shifted left by a fixed amount), never title-dependent and never inverted by a long title. Reading the chip's own geometry fixes the center and lets the band width track the chip.
- **Single source of truth.** `Bar.openMpris()`, `Bar.setMprisAnchor()`, and the launcher band test in `shell.qml` all read `mprisChipGlobalX`, so the clickable band and the popup anchor cannot drift apart again.
- **Degenerate geometry.** When the center is non-finite, `mprisChip.width <= 0`, or the window-relative center falls left of the chip's own `x`, the property returns the center-tab midpoint instead. The chip is `visible: active` and animates its width, so an inactive or not-yet-mapped chip has no meaningful geometry, and a stale zero reaching `MprisPopup.anchorX` would clamp the popup to the far left of the screen. While the chip is inactive the property consequently holds the fallback value rather than a chip center; that is documented behavior, not a defect, because every consumer gates on `mprisChipActive`.
- **Verification status:** the expression and the offset are measured — live geometry read from the running shell — and the fix is implemented in `Bar.qml`. No synthetic pointer click was performed. Still needs eyes: click feel at the chip's right edge and along the band boundary.

### Open decision (pending — not resolved by this spec)
- Whether the standalone popup should keep this launcher trigger, go dormant like `MetricsDropdown`, or be unified with the center dashboard Media pane (launcher chain opens `center-panel` on the Media tab instead) is **pending Ricardo's decision**. Both entry points currently exist and behave differently; nothing here recommends one

### Layout (top to bottom)
1. **Cover art** — `Layout.preferredHeight: 120`, `Image.PreserveAspectCrop`, hidden when `trackArtUrl` is empty
2. **Title** — primary text, `Text.ElideRight`
3. **Artist** — dim text, `Text.ElideRight`
4. **Progress bar** — `Layout.preferredHeight: 3`, fills `position / length` (0 when `length` is not positive)
5. **Controls** — previous `󰒮`, play/pause `󰏤`/`󰐊`, next `󰒭`
- The card has no explicit empty state: with no player, title and artist render as empty strings. In practice the popup is only opened while `bar.mprisChipActive` is true, which requires a player with title or artist metadata
- The play/pause glyph reflects `playbackState === MprisPlaybackState.Playing`; the card background, border, and debug border follow the same `Colors.base01` / `Theme.opacitySurface` / `Theme.radiusMd` treatment as the other overlay cards

### Controls behavior
- Previous: `player.previous()`
- Play/Pause: `player.togglePlaying()`
- Next: `player.next()`
- The popup's own `readonly property var player` uses the same selection priority as the chip and `Bar.mediaPlayer` (first `Playing`, else first available, else `null`)

## Compatibility
- Any MPRIS-compliant player (Spotify, VLC, MPV, etc.)
- Brave browser requires `plasma-browser-integration` package + Plasma Integration extension
