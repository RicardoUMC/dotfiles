# Design: Bar Curved Frame — Content-Sized Islands (Current)

## Technical Approach

Three `Rectangle` primitives at `leftTab`, `centerTab`, and `rightTab` content bounds form the bar background. Each island spans full bar height with per-corner radius control. The gaps between islands are **real transparent space** — no bridging connector, overlap, or ShapePath geometry. The transparent `PanelWindow` background shows through between sections, creating the breathing/islands visual.

The `bar.style: "silhouette" | "plain"` config model is preserved. Earlier approaches (ShapePath single path, top connector strip) are superseded — see notes below.

## Architecture Decisions

### Decision: Content-Sized Islands (composed rectangles at tab bounds)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **Content-sized Rectangles** at `leftTab`/`centerTab`/`rightTab` bounds | Simple Rectangles, each segment matches its content width, gaps are real transparent space | **Choose** — matches breathing/islands visual, no fixed-width assumptions |
| Top connector strip (z:1) + three bottom segments (z:0) | Two layers, same fill, could create invisible seam | Rejected (phase 2) — connector unnecessary when islands span full height; removed in `a1c9fa7` |
| Single ShapePath with PathCubic | Manual Bézier tuning; 14+ tuning passes failed | Rejected (phase 1) — unreliable coordinate math |

**Rationale**: Each island's width is driven by its BarTab's content width (`leftTab.width`, `centerTab.width`, `rightTab.width`). Gaps are the remaining space between tabs — no geometry constants needed. Per-corner radii on the gap-facing edges use existing `Theme.tabRadius`.

### Decision: Outer screen corners square, interior notch corners rounded

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **Square top/outer corners** | Clean straight edges at screen boundaries | **Choose** — matches user constraint |
| Rounded outer corners | Extra radius tokens, visual noise | Rejected — not in sketch intent |

**Rationale**: User confirmed outer screen corners can be straight. Interior curves use `Theme.tabRadius` on gap-facing edges.

### Decision: Three full-height island segments (supersedes top connector)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **Full-height segments** at tab bounds | Simple: each segment is `x: tab.x`, `width: tab.width`, `height: parent.height`, `y: 0` | **Choose** — commit `a1c9fa7`. Gaps extend full height, no connector needed |
| Top connector strip (z:1) + segments (z:0) | Two layers, same fill, must match notch depth calculations | Superseded — unnecessary complexity; gaps at full height give cleaner isometric visual |

**Rationale**: Making each island full-height (`y: 0, height: parent.height`) and positioning them at tab bounds eliminates all connector math. The visual gap is the full transparent space where no Rectangle exists — no hidden seam concern because overlapping Rectangles were never the goal for full-height approach. This matches the breathing/islands visual more closely. Outer edge radius is `0`, gap-facing edges use `Theme.tabRadius`.

## Visual Layout

```
┌──────────────────────┬──────────────┬───────────────────────┐
│ LEFT TAB CONTENT     │  GAP         │ CENTER TAB CONTENT    │
│ (leftSegment bg)     │  (real       │ (centerSegment bg)    │
│  square screen edge  │   trans-     │  rounded both sides   │
│  rounded at gap      │   parent)    │                       │
├──────────────────────┘              └───────────────────────┤
│                        GAP (real transparent)               │
├──────────────────────┐              ┌───────────────────────┤
│ RIGHT TAB CONTENT    │  (real       │                       │
│ (rightSegment bg)    │   trans-     │                       │
│  rounded at gap      │   parent)    │                       │
│  square screen edge  │              │                       │
└──────────────────────┘              └───────────────────────┘
```

- Each island's `x`/`width` = its BarTab's `x`/`width`
- Gaps are the space between BarTab bounds — no explicit gap geometry constants
- Per-corner radii: outer/screen edges = 0, gap-facing edges = `Theme.tabRadius`
- All islands: `y: 0`, `height: parent.height`

## Data Flow

```
config.json ──→ Theme.applyConfig() ──→ barStyle, barNotchGapWidth, barNotchDepthRatio
                                               │
                     ┌─────────────────────────┘
                     ▼
Bar.qml: 3 Rectangle islands { visible: barStyle === "silhouette" }
    │
    ├── leftSegment:   x: leftTab.x,   width: leftTab.width
    ├── centerSegment: x: centerTab.x, width: centerTab.width
    └── rightSegment:  x: rightTab.x,  width: rightTab.width
                                     │
                                     ▼
                               BarTab (transparent bg, z: 1-2)
                                     │
                               innerRow content layout
```

No data flow changes for IPC, overlays, or shell.qml connections — visual only. Segment positions derived from existing `BarTab.x`/`width` values; no separate coordinate computation needed.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `quickshell/.../bar/Bar.qml` | Modify | Remove ShapePath block; add 3 content-sized Rectangle islands at tab bounds; add debug highlight mode; keep IPC, tab layout, z-ordering |
| `quickshell/.../theme/Theme.qml` | Modify | Add `barNotchGapWidth` + `barNotchDepthRatio`; keep `barStyle`, `tabRadius`, `tabBgOpacity` |
| `quickshell/.../config.json` | Modify | Add `bar.notchGapWidth: 30`, rename `curveDepthRatio` → `notchDepthRatio: 0.2`, add `debug.barSilhouette` |

**No changes**: BarTab.qml (already clean — no bg, no border), shell.qml, qmldir files.

## Interfaces / Contracts

```qml
// Theme.qml — new properties
property real barNotchGapWidth: 30       // px gap at each section boundary
property real barNotchDepthRatio: 0.2    // reserved for future expanded center (unused in normal state)
property bool debugBarSilhouette: true   // high-contrast debug mode for visual tuning

// Bar.qml — island geometry pattern (3 content-sized segments):
readonly property color segmentFill: Theme.debugBarSilhouette
    ? Qt.rgba(1.0, 0.2, 0.2, 0.65)
    : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.tabBgOpacity)
readonly property int segmentBorderWidth: Theme.debugBarSilhouette ? 1 : 0
readonly property color segmentBorderColor: Theme.debugBarSilhouette ? "#ff3344" : "transparent"

// Per-segment pattern (applied to each of 3 Rectangles):
// leftSegment:   x: leftTab.x,   width: leftTab.width
// centerSegment: x: centerTab.x, width: centerTab.width
// rightSegment:  x: rightTab.x,  width: rightTab.width
// all: y: 0, height: parent.height, z: 0
// all: visible: Theme.barStyle === "silhouette"
// topLeftRadius/topRightRadius: 0 on screen edges, Theme.tabRadius on gap edges
// bottomLeftRadius/bottomRightRadius: 0 on screen edges, Theme.tabRadius on gap edges
```

No new QML types → no qmldir changes.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Lint | Bar.qml, Theme.qml | `qmllint` — 0 errors |
| Visual (CP1) | Normal state, silhouette mode | Three content-sized islands at tab bounds with transparent gaps, breathing visual |
| Visual (CP2) | MPRIS active | Same height, no layout shift |
| Visual (CP3) | MetricsDropdown open | Overlay above apps, bar unchanged |
| Visual (CP4) | `bar.style: "plain"` | Transparent bg, no segments visible |
| Runtime | IPC coordinates, overlay interactions | All existing IPC paths functional |
| Debug | `debug.barSilhouette: true` | High-contrast red fill/border on actual island bounds |

## Migration / Rollout

1. **Prep**: Working tree clean at `a1c9fa7` — composed islands checkpoint committed
2. **Apply**: Implementation in 3 checkpoint commits — see `git log --oneline 5b85301..HEAD`
3. **Verify**: `qmllint` pass → restart Quickshell → CP1–CP4 visual checkpoints
4. **Fallback**: `git checkout a1c9fa7 -- quickshell/.config/quickshell/bar/Bar.qml` restores composed islands

## Rollback Plan

1. **File revert**: `git checkout a1c9fa7 -- quickshell/.config/quickshell/bar/Bar.qml quickshell/.config/quickshell/theme/Theme.qml quickshell/.config/quickshell/config.json`
2. **Config compat**: Old `curveDepthRatio` key silently accepted in `applyConfig()`
3. **No data loss**: Checkpoint is committed — full recovery via `git checkout a1c9fa7`

## Remaining Work

- [ ] **Visual tuning**: Runtime adjustment of island appearance (gaps, radii, colors) — requires Quickshell restart each iteration
- [ ] **Set `debug.barSilhouette: false`** in config.json before final/archive
- [ ] **Prune `barCurveDepthRatio` legacy property** from Theme.qml before archive (functional fallback present)
- [ ] **Reconcile runtime CPs**: CP1–CP4 require running Quickshell and visual inspection
- [ ] **Final verify + archive**: Run verify phase, resolve any remaining warnings, then archive
