# Staged GPU glass prototype for curved islands

## Goal
Validate exact curved-mask rendering and performance with a controlled client-owned texture before attempting live-window backdrop glass. Keep `main`'s stable translucent island fallback unchanged and avoid coupling material experiments to input, routing, focus, Escape, overlays, or monitor ownership.

## Scope
- Work on `feat/global-surface-system` only.
- Stage 1 is synthetic/controlled: no screen capture, no compositor blur rule, no new interactive surface.
- The prototype must be opt-in and removable without changing the production baseline.
- Future configurable-bar position, visibility, style, and dashboard attachment remain unimplemented; the prototype must not hardcode a competing ownership model.

## Tasks
1. **Define the material/geometry boundary and opt-in configuration contract (implemented).**
   - `Theme.islandGpuPrototypeTarget` reads `surface.islandGpuPrototypeTarget`.
   - The default is `none`; the only accepted future target is `left`; invalid values fall back to `none`.
   - `surface.islandNativeBlur` remains an independent switch and keeps its existing `false` behavior.
   - `bar/IslandGpuPrototype.qml` is a registered, passive visual-only component. It masks a client-owned synthetic gradient through `MultiEffect`; it is not a live desktop backdrop and is not wired into `BarSection`.
2. **Implement a controlled-texture GPU mask prototype for one island (implemented).**
   - `BarSection` instantiates the passive prototype over the existing authoritative `sectionMask` only when `Theme.islandGpuPrototypeTarget === "left"` and the section is the left section.
   - The existing masked `MultiEffect` remains visible for every non-target section and whenever the target is not explicitly `left`; the repository default remains `none`.
   - The synthetic client-owned texture is a deterministic gradient with a subtle looping highlight and a bounded `MultiEffect` blur. This is an animation/mask-cost probe only, not desktop backdrop blur.
   - Opt in by setting `surface.islandGpuPrototypeTarget` to `"left"` in `quickshell/.config/quickshell/config.json`; no input, focus, routing, or overlay surface is added.
3. Verify edge fidelity, animation cost, Qt6 lint, reload, and fallback behavior.
4. Review the result and decide whether a bounded native/live-backdrop feasibility prototype is justified.
5. Specify a passive bounded native-blur feasibility surface for one island.
6. Implement the one-island native feasibility prototype behind an opt-in switch (implemented).
   - `Theme.islandNativePrototypeTarget` accepts only `none|left` and defaults to `none`.
   - `Theme.islandNativePrototypeScreen` is an exact screen-name selector and defaults to empty; non-string selectors disable the prototype.
   - `bar/IslandNativePrototype.qml` is a passive, visual-only `Top` PanelWindow explicitly pinned to its owning Bar screen. It uses `WlrKeyboardFocus.None`, `ExclusionMode.Ignore`, top+left anchors, bounded left-section geometry, a transparent color, and a non-null empty input mask.
   - Its `BackgroundEffect.blurRegion` is a helper-local bounded `Region` with rounded right/bottom edges. This is explicitly a feasibility approximation, not the production Canvas mask.
   - `Bar.qml` creates the helper only when the target is `left` and the exact configured screen name matches. It does not alter `BarSection`, production masks, input union, RCC, shell coordination, services, or overlay ownership.
   - `surface.islandNativeBlur` remains `false`; `surface.islandGpuPrototypeTarget` remains `none`; the native helper is not active by default.
7. Verify stacking, geometry, fallback, latency, and interaction invariants.
8. Review the evidence and decide whether to keep, discard, or redesign the prototype.

## Verification evidence
- Opt-in preview with `surface.islandGpuPrototypeTarget: "left"`: Qt6 lint, JSON parse, diff check, and soft reload passed; Quickshell reached `Configuration Loaded` without `ERROR`. Screenshot: `/tmp/quickshell-recordings/island-gpu-prototype-left.png`. The synthetic blue material stayed within the left island silhouette; center/right remained on the fallback.
- Default restored to `surface.islandGpuPrototypeTarget: "none"`: assertion, diff check, and soft reload passed; screenshot `/tmp/quickshell-recordings/island-gpu-prototype-disabled.png` showed the dark fallback islands on both displays with no synthetic material and no post-reload `ERROR`.
- These captures validate client-owned mask rendering only; they do not prove a live desktop backdrop source.
- Native review `review-cc5b5d20cf72d3aa` was approved and acknowledged. Informational findings only: disabled animation lifecycle and invalid-target coercion; no correction was opened.

## Stage 2 authorization
- The user authorized a bounded native feasibility prototype for one island.
- Scope remains experimental and opt-in: no fullscreen blur rule, no screen capture, no replacement of the production Bar, no new input/focus/routing owner, and no default activation.
- Feasibility contract: a helper is owned by the existing Bar, explicitly pinned to its screen, Top-layer, `ExclusionMode.Ignore`, empty non-null input mask, keyboard focus `None`, and no IPC/overlay/service responsibilities. Same-layer visual ordering is a gate, not an assumption; an above-Bar helper is a failed feasibility result.

## Stage 2 implementation contract

The native helper is a bounded feasibility probe only. It has no screencopy, fullscreen rule, `MouseArea`, IPC, focus, routing, overlay, service, or input ownership logic. Its same-layer ordering relative to the owning Bar is part of feasibility validation: an above-Bar helper is a failed result, not an accepted assumption. The existing translucent BarSection rendering remains authoritative whenever the opt-in target/screen pair is not selected.

## Stage 2 verification and decision
- With `surface.islandNativePrototypeTarget: "left"` and `surface.islandNativePrototypeScreen: "DP-1"`, the helper mapped as a bounded 110×52 Top surface at `(1920,0)` on DP-1 only. Qt6 lint, JSON, diff check, reload logs, and Hyprland config errors were clean within known lint warnings.
- The helper visibly composited **above** the production Bar and blurred the DP-1 workspace chip/text. This fails the required stacking gate; it is not an acceptable production architecture. DP-2 remained without the helper.
- Restoring target `none` and screen `""` removed the helper from both layer lists, restored the unobscured fallback, and reloaded without `ERROR`. Screenshot evidence: `/tmp/quickshell-recordings/island-native-prototype-dp1.png` and `/tmp/quickshell-recordings/island-native-prototype-disabled.png`.
- Decision: do not promote same-layer independent PanelWindow helpers. Keep the experiment disabled while the next architecture investigates a parent/subsurface or compositor-integrated ordering/backdrop path; do not add a stacking rule or screen capture workaround.

## Non-goals
- No live desktop capture or feedback-prone screencopy pipeline.
- No fullscreen compositor blur rule.
- No dedicated interactive island window.
- No configurable-bar implementation.
- No changes to services, overlay ownership, focus, Escape, input masks, or N-monitor routing.

## Architecture constraints
- Shared geometry describes the silhouette; the material backend consumes it.
- Visible mask, input region, and blur/material region remain separate representations.
- The controlled texture is not evidence of live-window backdrop correctness.
- Existing translucent fill remains the authoritative fallback.

## Acceptance criteria
- Prototype is disabled by default and does not alter the current shell when disabled.
- The selected island uses the existing curved `sectionMask` with antialiased edges over a controlled texture; the explicit `left` target is the only active preview.
- No source captures, compositor rules, extra focus/input surfaces, or service mutations are introduced.
- Static and live checks demonstrate no reload errors and no measurable regression in the disabled baseline.
