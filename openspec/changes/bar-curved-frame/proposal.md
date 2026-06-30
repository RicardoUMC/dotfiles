# Proposal: Bar Curved Continuous Frame

> **Evolution**: This proposal originally described a single ShapePath approach. After ~14 tuning passes, the ShapePath approach was abandoned in favor of **composed Rectangle segments** at content bounds. See `design.md` for the current architecture. The `bar-styling` capability intent (silhouette/plain toggle) remains unchanged; the implementation strategy shifted. This document is preserved for traceability; `design.md` is the authoritative technical reference.

## Intent

The top bar looks fragmented — three opaque per-tab cards on a transparent panel with a thin rail. The user's sketch calls for a single continuous background surface with concave transitions between sections. This change replaces the layered composite with a unified `ShapePath` silhouette that IS the bar background, matching the sketch and eliminating visual seams.

## Scope

### In Scope
- Single `ShapePath` silhouette as sole bar background (fill + 1px stroke)
- Opaque BarTab backgrounds removed → content sits on silhouette
- Rail Rectangle eliminated (top portion of silhouette replaces it)
- CenterTab blue accent border removed entirely from BarTab.qml
- `bar.style` config toggle with values `"silhouette"` / `"plain"`
- Revert failed uncommitted attempt (73 lines in Bar.qml, Theme.qml, config.json)

### Out of Scope
- Taller/deep center section (future overlay PanelWindow)
- Animations or transitions on style toggle
- Content layout changes within sections (Workspaces, ClockChip, etc.)
- Changes to IPC, shell.qml, overlay manager

## Capabilities

### New Capabilities
- `bar-styling`: Controls continuous curved silhouette background via `bar.style` config. Supports `"silhouette"` (curved continuous shape with fill + 1px border around entire bar) and `"plain"` (transparent background, content visible without opaque tab cards).

### Modified Capabilities
- None (no existing specs in `openspec/specs/`).

## Approach

Approach 1 from exploration: Pure `ShapePath` Silhouette.

1. **Revert** failed uncommitted attempt via `git checkout -- <files>`.
2. **Bar.qml**: Remove `rail` Rectangle. Add a Shape (z:0) with one `ShapePath` — top edge straight with `PathArc` corners, bottom edge with `PathCubic` concave transitions between left/center/right sections. Single `fillColor` + 1px `strokeColor`. Explicit geometry inset by `strokeWidth / 2`.
3. **BarTab.qml**: Remove opaque `bgSource` Rectangle, remove `border` Rectangle, remove `centerAccent` (blue left-border). Keep layout, content, IPC signals. Add `silhouetteOnly: bool` property for mode awareness.
4. **Theme.qml**: Add `bar.style` config binding. Keep `tabRadius` for top corners. Add `curveDepth` or compute proportional from bar height.
5. **config.json**: Replace `bar.outerFrame` boolean with `bar.style` string (`"silhouette"` default).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `quickshell/.../bar/Bar.qml` | Modified | Remove rail, add ShapePath silhouette, coordinate heights |
| `quickshell/.../bar/BarTab.qml` | Modified | Remove bg, border, accent; add `silhouetteOnly` property |
| `quickshell/.../theme/Theme.qml` | Modified | Add `bar.style` binding, remove `outerFrameEnabled` |
| `quickshell/.../config.json` | Modified | Replace `bar.outerFrame` with `bar.style` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| ShapePath stroke clips at PanelWindow edge | Med | Explicit geometry inset by `strokeWidth/2` instead of `anchors.fill` |
| Concave "V" stroke artifact at transition point | Med | Use `joinStyle: Qt.RoundJoin`; fallback to `strokeColor: "transparent"` |
| Tab positions not ready when ShapePath renders | Low | `onXChanged`/`onWidthChanged` recomputes; renders correct within one frame |
| Regression: IPC coordinates | Low | No anchoring changes — `powerBtnGlobalX`, etc. remain correct |

## Rollback Plan

1. **Revert failed attempt**: `git checkout -- quickshell/.config/quickshell/bar/Bar.qml quickshell/.config/quickshell/config.json quickshell/.config/quickshell/theme/Theme.qml`
2. **Full revert**: `git diff HEAD --name-only | xargs git checkout --` discards all uncommitted changes.
3. **Commit revert**: If merged, revert the commit conventionally.

## Dependencies

- QtQuick.Shapes import (available in Qt6/QtQuick)
- qmllint pass required before commit

## Success Criteria

- [ ] **SC1**: Single continuous background visible with no seams between rail/tabs
- [ ] **SC2**: Concave transitions at section boundaries with smooth curves
- [ ] **SC3**: All three sections same visual height in normal state
- [ ] **SC4**: 1px border visible around entire bar silhouette
- [ ] **SC5**: `bar.style: "plain"` shows content on transparent background (no opaque cards)
- [ ] **SC6**: All IPC coordinates correct (powerBtnGlobalX, mprisChipGlobalX)
- [ ] **SC7**: qmllint passes with zero errors
- [ ] **SC8**: Changed lines ≤ 400 (forecast: ~150–200)
