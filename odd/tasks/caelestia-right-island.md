# Caelestia-inspired right-island visual pass

Status: completed

## Goal
Adapt selected Caelestia visual principles to the existing Tokyo City right island without copying code, changing overlay ownership, or turning the shell into a Material 3 clone.

## Scope decisions
- Approved scope: stateful visual grammar plus a scoped smooth-motion pilot.
- Configurability is an acceptance criterion: user-tunable structure belongs in `Theme.qml` and `config.json`; colors/fonts stay in `Colors.qml`; motion gets a small high-leverage token surface rather than per-component literals or per-curve token sprawl.
- Work is split into two reviewable implementation units:
  1. Right-island chip grammar and service-state communication.
  2. Shared Motion primitive applied only to the right island/control-center pilot.
- Notification surface redesign remains a later, separate unit unless exploration shows a small safe improvement belongs in unit 1.
- No hover-open behavior, no layer changes, no service command semantics changes.
- Preserve the intentionally untouched `wezterm/.wezterm.lua`.

## Reference evidence
- Local reference: `/home/unseen/src/reference/Caelestia`, `caelestia-dots/shell`, commit `454f46d`.
- Curves: `plugin/src/Caelestia/Blobs/shaders/blob.frag`, `modules/utilities/RecordingDeleteModal.qml`.
- Motion: `components/Anim.qml`, `components/AnchorAnim.qml`, `components/CAnim.qml`, `plugin/src/Caelestia/Config/tokens.hpp`.
- Notifications: `modules/notifications/Content.qml`, `modules/notifications/Notification.qml`, `modules/sidebar/NotifGroup.qml`.
- State-layer/card grammar: `components/StateLayer.qml`, `components/controls/ButtonBase.qml`, `modules/utilities/cards/Toggles.qml`, `modules/bar/popouts/Network.qml`.

## Current evidence
- Screenshot `/tmp/pi-clipboard-028316a4-844b-466d-a4f2-81182b461373.png` shows five uniform outlined chips; debug silhouette is enabled.
- Current chip implementation is `bar/RightIslandIconButton.qml`; construction is in `bar/Bar.qml`.
- Service states are already available from `WifiService`, `BluetoothService`, `AudioService`, and notification state injection.
- Current `Theme.qml` has structural and basic animation duration tokens but no shared motion family/curve primitive.
- User will provide a non-debug island and opened-panel image for visual validation when available.
- Qt 6.11.2 motion-API facts established by offscreen runtime probes (unit 2), none of them assumed from docs:
  - `easing.bezierCurve` is accepted declaratively and imperatively, but a 4-value list is rejected at runtime (`QEasingCurve: Invalid bezier curve`) and the animation degrades to **linear**; the 6-value form ending in the required `(1, 1)` point applies correctly.
  - `qmllint` does **not** catch the 4-value form — it lints clean, so lint success is not curve evidence.
  - Inline `component` declarations inside a `pragma Singleton` cannot see the enclosing `id` (`ReferenceError`); they must bind through the singleton type name.
  - A capability probe written as `property Component probe: Component { ... }` never instantiates, so its `onCompleted` never runs; the probe must be a declared child object.
  - Verified curve shapes are monotonic and stay in `[0, 1]`: effects `[0.31, 0.94, 0.34, 1.0]` reaches 0.94 at 50% progress; spatial `[0.38, 1.0, 0.22, 1.0]` reaches 0.97. Caelestia's own spatial curves overshoot to 1.01–1.09, which is why they were not adopted directly — the control-center body height is content-driven and an overshoot would resize the panel past its own content.

## Tasks
1. Map current right-island state semantics and token surfaces against Caelestia's state-layer and motion principles. Compare a no-new-component adaptation against a shared primitive; choose based on reuse and review risk. — DONE: shared primitive chosen; the hover/pressed fill with parent-radius inheritance is reused by the four service chips and the power button, and removing it from RightIslandIconButton would have duplicated the state-opacity ladder in five places.
2. Implement stateful right-island visual grammar: remove generic outline dependence, add tokenized fill/state-layer/shape hierarchy, distinguish power from service chips, and communicate real service state without changing interaction routing. Expose broadly useful island geometry/opacity/state-layer values through `Theme.qml` + `config.json`. — DONE (unit 1): new `bar/StateLayer.qml` passive overlay primitive (registered in `bar/qmldir`); `RightIslandIconButton` rebuilt around fill/shape/accent state (disabled/on/active/warning, no border, new `disabled` input fed from WifiService/BluetoothService adapter state in `Bar.qml`); power button restyled as a pill with resting red tint and red state layer, popup behavior untouched; one semantic hairline separator between service chips and power; seven new `island*` Theme tokens under the `island.*` config group. No Motion singleton yet (unit 2).
3. Add a `Motion` singleton/primitive only if Qt 6.11/Quickshell 0.3.1 validation supports it; apply named spatial/effects intents to right-island and control-center transitions only. Keep global migration out of scope, and expose only high-leverage duration/scale controls. — DONE (unit 2): `theme/Motion.qml` singleton registered in `theme/qmldir`, exposing two intents (`Effects`, `Spatial`) plus a color variant (`EffectsColor`) as drop-in inline animation types, with timing derived from `Theme.animFast`/`animSlow` times one new `Theme.animScale` knob (`anim.scale`, clamped 0.25–3.0, default 1.0 preserves current timing). No per-curve config is exposed.
   Runtime validation on Qt 6.11.2 (offscreen, not assumed from docs): `easing.bezierCurve` **works**, but only in the 6-value control-point form `[x1, y1, x2, y2, 1, 1]`. The CSS-style 4-value form is rejected with `QEasingCurve: Invalid bezier curve` and **silently animates linear**, so the singleton probes curve support against a real `NumberAnimation` at startup and falls back to `Easing.OutCubic` when a build does not apply it. Inline `component` types were confirmed unable to reference the enclosing `id`, so they bind through the `Motion` singleton name; a `Component {}`-defined probe was confirmed never to instantiate, so the probe is a real child `Item`.
   Migrated call sites: `bar/StateLayer.qml` opacity behavior (was `Theme.animFast` + `Easing.OutCubic` literals) → `Motion.Effects`; `bar/RightControlCenter.qml` `panelBody` gained `Behavior on height` → `Motion.Spatial` (was an instant jump on expand/section-switch); `bar/RightIslandIconButton.qml` chip fill gained `Behavior on color` → `Motion.EffectsColor` (service-state flips; the hover-driven icon color is deliberately left instant). No exit animation was added for `PanelWindow.visible` — shell.qml's overlay manager tears that surface down synchronously, which is out of scope.
4. Validate with Qt 6 qmllint, manual reload/log evidence, and visual comparison with debug off. Run design-system guardian checks and sync relevant docs. — DONE: Qt 6.11 `qmllint` clean on `theme/Motion.qml`, `bar/StateLayer.qml`, `bar/RightIslandIconButton.qml`; `bar/RightControlCenter.qml` reports only the documented `uncreatable-type` on `PanelWindow`, and `theme/Theme.qml` only its two pre-existing `[unqualified]` warnings. Offscreen runtime evidence captured for curve support, fallback, scale propagation, and the `anim.scale` clamp table. Doc sync done via `sync-docs`: `AGENTS.md` (architecture rows for `StateLayer.qml`/`Motion.qml`/power pill, new "Motion system" section incl. the `ComponentBehavior: Bound` prohibition, seven `island.*` + `animScale` token entries, Caelestia reference note), `DESIGN.md` (Caelestia inspiration section, right-island state-grammar design rule, token tables), `SPECS.md` (honest status notes), `specs/bar.md` (right island rewritten: four service chips + configurable semantic divider + power pill), `specs/theme-system.md` (island grammar token requirement, Motion singleton requirement with probe/fallback/clamp/prohibition, schema + scenarios), `specs/right-island-control-center.md` (status, inspiration, collapsed-island and animation-model updates). Live reload, compositor verification, and visual comparison were confirmed by the user; no debug-off screenshot is required.
5. Commit each implementation unit separately and push only after verification and explicit delivery authorization — DONE: user-authorized commit `9f72c83` pushed to `origin/main`.

## Non-goals
- No Caelestia code copying or vendoring.
- No C++ SDF/blob plugin.
- No hover-open overlays.
- No replacement of the existing notification engine or focused-screen policy in this pass.
- No broad migration of all shell animations. Unmigrated call sites (`Bar.qml`, `CenterDashboard.qml`, `MetricCard.qml`, `MprisIndicator.qml`, `AudioControlCard.qml`, the notification toast, and the `InOutSine` pulses in the Wi-Fi/Bluetooth cards) intentionally still use `Theme.anim*` directly; the `Motion` primitive is opt-in per call site for now.
