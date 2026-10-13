# Configurable Bar Positioning

Status: Top/bottom baseline positioning and left physical placement implemented in working tree; right refinement is next. Manual pointer-level dashboard/input verification remains pending. Delivery pending explicit commit request

## Goal
Implement the physical placement phase of the configurable bar so each per-monitor `Bar` instance renders from its resolved `bar.position`: `top`, `bottom`, `left`, or `right`, while preserving the current island style and the top-position baseline. Top and bottom remain the baseline physical placements. Left physical placement is implemented by reusing the horizontal top island source and applying a 90-degree counter-clockwise rotation to visible notch masks, decorative wraps, and bounded native blur Regions; content remains upright and stacked vertically, with left-side overlay offsets. Right refinement is next.

## Source of truth
Use only the existing normalized configuration resolver in `Theme.effectiveBarConfig(screenName)`. Do not introduce another configuration system. `visibility: "edge-reveal"`, `style: "continuous"`, and `dashboard.attachment: "detached"` remain inert for this session.

## Scope
- Resolve the effective position per `ShellScreen` through the existing `barConfig` injected by `shell.qml`.
- Apply correct layer-shell anchors, margins, and `exclusiveZone` for top, bottom, left, and right.
- Support horizontal composition for top/bottom, including the bottom centered vertical mirror of visible masks and wraps.
- Adapt island section layout, masks, wraps, gaps, input masks, and native blur geometry to the active edge; left placement reuses the horizontal top island source with a 90-degree counter-clockwise rotation for visible notch masks, decorative wraps, and bounded native blur Regions while content remains upright and stacked vertically; right refinement remains future work.
- Preserve independent per-monitor instances and explicit child surface pinning to `root.screen`.
- Update documentation to distinguish implemented positioning from still-inert visibility, continuous style, and detached dashboard.

## Out of scope
- Edge reveal behavior.
- Continuous bar rendering.
- Detached dashboard rendering.
- Dynamic colors or wallpaper-derived palettes.
- Monitor index or ordering configuration.
- Overlay manager changes except strictly necessary coordinate fixes.
- Pushes or delivery operations.

## Tasks
- [x] Map current bar geometry and direction assumptions, including child overlay coordinates.
- [x] Implement top/bottom surface anchoring, reservation, section composition, masks, wraps, bottom-center cutout, and edge-aware blur while preserving `top`.
- [x] Establish left/right positioning geometry and overlay coordinate routing; left reuses the horizontal top island source with a 90-degree counter-clockwise rotation for visible notch masks, decorative wraps, and bounded native blur Regions while controls remain upright and stack vertically; right refinement remains next.
- [x] Update docs for the implemented positioning boundary.
- [x] Verify Qt lint, reload, geometry/input/overlay behavior, and mixed monitor positions; live pointer-level visual checks remain pending.

## Verification evidence
- Work-unit commit: `0f8b7c6` (`feat(bar): add top and bottom positioning`).
- Qt 6 `qmllint` passed on all modified QML with documented baseline warnings only.
- `git diff --check` passed.
- Soft reload reached `Configuration Loaded` without errors after the final mask-loop correction.
- Temporary configurations exercised top, bottom, left, right, and mixed DP-1-left/DP-2-right placement; `hyprctl layers` showed per-output geometry and `hyprctl monitors` showed left/right reservations `[82,0,0,0]` and `[0,0,80,0]`.
- IPC power-menu open/close remained functional on the restored top configuration.
- Direct pointer-level input-mask and dashboard Escape/outside-click verification remain pending because they require manual interaction; no native review approval is claimed.
- Bottom follow-up: `NotchIslandMask.qml` now inverts horizontal notch corners and rounded curvature for `edge: "bottom"`; top and vertical geometry remain unchanged. Bottom reload and screenshot inspection passed; manual click validation remains pending.
- Side follow-up: vertical wraps now grow inward (`left` → right, `right` → left), with distinct outer rounded and inward notch-facing corners. Mixed left/right runtime screenshot inspection passed; manual click validation remains pending.
- Side-corner follow-up: corrected vertical corner mapping so `left` has outer top-left/bottom-left ornaments and inward top-right/bottom-right notches; `right` mirrors the mapping. A visibility-gating bug was then fixed so physical outer corners render independently of horizontal corner flags; temporary left/right runtime capture now shows the missing upper ornament.
- Bottom clarification: the reported missing ornament was on the horizontal left island while positioned at `bottom`, not on a vertical `left` bar. Added mirrored top outer corner masks for bottom mode, then corrected `BarSection` bottom origin/targetProxy offsets so wraps are not clipped. Bottom runtime screenshot now shows both left and right inward adornments.
- Bottom mirror follow-up: replaced additive bottom corner patches with a true top-to-bottom mirror for `NotchIslandMask` and `IslandBlurRegion`, including body curvature, caps, wraps, and native blur geometry.
- Visible-mask follow-up: horizontal `bottom` now reuses the top `NotchIslandMask` geometry with a centered vertical scale mirror, keeping opacity-only mask coverage aligned with the blur reference.
- Current boundary: top/bottom baseline placement and left physical placement are implemented. Left rotates the horizontal top island source 90 degrees counter-clockwise for visible notch masks, decorative wraps, and bounded native blur Regions; content remains upright and stacks vertically, with overlay offsets. Right refinement is next.
- Blur-alignment follow-up: the nested-ellipse local-coordinate experiment was reverted after artifacts; the prior Region coordinate composition remains intact.
- Wrap-mask follow-up: horizontal bottom wrap corners now retain the top primitives and use centered vertical Scale(-1), matching the literal visible-mask reflection.

## Decisions
- Work on `main` without committing unless Ricardo explicitly requests a commit; repository instructions forbid commits without explicit request.
- Treat visual positioning as non-test-first because there is no deterministic unit runner for layer-shell geometry; use source inspection, Qt 6 lint, Quickshell reload logs, and live compositor checks instead.
