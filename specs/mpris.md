# MPRIS

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/bar/MprisIndicator.qml`, `MprisPopup.qml`

## Description
Music/media player integration via MPRIS D-Bus protocol. Composed of a bar chip and a popup player.

## Indicator Chip

### Visibility
- Visible only when a player exists AND has a non-empty `trackTitle` or `trackArtist`
- Hidden when no media is playing or paused
- Width animates in/out (180ms, OutCubic easing)

### Display
- Icon: `󰎆` (playing) or `󰎇` (paused/stopped) — Nerd Font, accent color
- Title: truncated to 28 characters with `…`
- Click: toggles MPRIS popup

### Player selection priority
1. First player with `playbackState === Playing`
2. Fallback: first available player

## Popup Player

### Trigger
- Opens on chip click
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
