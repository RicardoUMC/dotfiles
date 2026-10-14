# Configurable Bar — Left Position

Status: Implemented in code; manual pointer-level dashboard/input verification pending

## Goal
Refine the `left` physical bar position as a distinct visual unit. The bar remains per-monitor and uses the existing normalized `Theme.effectiveBarConfig(screenName)` resolver.

## Implemented boundary
- Left placement is anchored to the physical left edge of each selected monitor.
- Controls stack vertically so the bar remains narrow; glyphs remain upright.
- Left reuses the horizontal top island source and applies a 90-degree counter-clockwise rotation to visible notch masks, decorative wraps, and bounded native blur Regions; content remains upright and stacked vertically.
- Bar-owned overlays use left-side offsets outside the reserved bar width while remaining pinned to the owning screen.
- Top and bottom remain the baseline physical placements and are unchanged by this unit.
- Right refinement is next; it is not claimed as the completed mirrored treatment.

## Out of scope
- Edge reveal; `edge-reveal` remains current always-visible behavior.
- Continuous style; continuous rendering remains inert.
- Detached dashboard; detached dashboard rendering remains inert.
- Dynamic colors.
- Right-position refinement.

## Tasks
- [x] Define left-edge geometry and vertical orientation.
- [x] Stack left-position controls vertically without rotating glyphs.
- [x] Adapt center dashboard and Bar-owned overlay coordinates for left.
- [x] Reuse the horizontal top island source with a 90-degree counter-clockwise rotation for visible notch masks, decorative wraps, and bounded native blur Regions while keeping content upright and vertically stacked.
- [ ] Manually verify pointer-level input regions, dashboard outside-click/Escape behavior, and visual compositor behavior.
- [x] Update documentation with the implemented left boundary.

## Verification evidence
- Source/runtime work establishes left placement by rotating the horizontal top island source 90 degrees counter-clockwise for visible notch masks, decorative wraps, and bounded native blur Regions; content remains upright and vertically stacked, with left-side overlay offsets.
- Manual pointer-level dashboard/input verification is still pending.
- This task does not claim native review approval.
- Work-unit commits: `307bc06 feat(bar): rotate left island geometry`; `3606d22 fix(bar): render left debug silhouette`.

## Decisions
- Existing top/bottom implementation is the baseline and must not regress.
- The left unit is a vertical physical placement, not a generic monitor-order assumption.
- Left geometry uses one canonical horizontal source, rotated as a whole counter-clockwise with `(u,v) -> (v,W-u)`; the same source drives debug and production masks.
- Right refinement follows later and should mirror the left design only after its own geometry and interaction checks.
