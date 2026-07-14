# MPRIS

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/bar/MprisIndicator.qml`, `CenterDashboard.qml`, `MprisPopup.qml`

## Description
Music/media player integration via MPRIS D-Bus protocol. Composed of a bar chip, the center dashboard Media pane, and a popup player kept for launcher fallback/future explicit triggers.

## Indicator Chip

### Visibility
- Visible only when a player exists AND has a non-empty `trackTitle` or `trackArtist`
- Hidden when no media is playing or paused
- Width animates in/out (180ms, OutCubic easing)

### Display
- Icon: `󰎆` (playing) or `󰎇` (paused/stopped) — Nerd Font, accent color
- Title: truncated to 28 characters with `…`
- Click: selects the center dashboard Media tab and opens the in-place center dashboard when clicked from the visible compact bar chip

### Player selection priority
1. First player with `playbackState === Playing`
2. Fallback: first available player

## Center Dashboard Media Pane

### Trigger
- Opens from visible compact center MPRIS chip clicks
- The chip click selects the Media tab before opening the in-place center dashboard
- The expanded center dashboard hides the compact clock/media header, so media controls live in the dashboard body rather than in an expanded chip target

### Controls behavior
- Previous: `player.previous()`
- Play/Pause: `player.togglePlaying()`
- Next: `player.next()`
- Empty state: `No media playing` when no player is available

## Popup Player

### Trigger
- Remains available for launcher outside-click fallback or a future explicit trigger
- Closes on click outside, Escape, or workspace change
- Belongs to `bar-primary` context group — opening closes other primary overlays

### Layout (top to bottom)
1. **Cover art** — 120px height, `PreserveAspectCrop`, hidden if `trackArtUrl` is empty
2. **Title** — primary text, elided
3. **Artist** — dim text, elided
4. **Progress bar** — 3px height, fills based on `position / length`
5. **Controls** — previous `󰒮`, play/pause `󰏤`/`󰐊`, next `󰒭`

### Controls behavior
- Previous: `player.previous()`
- Play/Pause: `player.togglePlaying()`
- Next: `player.next()`

## Compatibility
- Any MPRIS-compliant player (Spotify, VLC, MPV, etc.)
- Brave browser requires `plasma-browser-integration` package + Plasma Integration extension
