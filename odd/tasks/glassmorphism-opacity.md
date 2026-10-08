# Global configurable opacity and glass surfaces

## Goal
Make opacity and Glassmorphism a global visual-surface system for the bar/islands, center dashboard, right control center, launcher, notifications, MPRIS, metrics dropdowns, and their neutral nested cards. Preserve backend behavior, routing, focus, Escape, multi-monitor ownership, input masks, and the Tokyo City semantic palette.

## Tasks
1. Define and document the global configuration contract for `surface.mode` (`solid`, `translucent`, `glass`), global opacity defaults, role-specific surface alphas, validation, and fallback behavior. The shipped default remains `solid` with opacity `1.0`.
2. Add a small Theme surface grammar that applies policy to backgrounds only; keep text, icons, controls, artwork, semantic accents, urgency, selection, hover/press states, progress, and debug masks independent.
3. Apply the shared surface grammar to bar/islands, center dashboard, right control center, launcher, notification toasts, MPRIS, metrics dropdowns, and neutral nested cards without changing their ownership or input/focus behavior.
4. Implement compositor-backed blur for the shared visual surfaces through an opt-in `surface.nativeBlur` property (default `true`) and Quickshell's native `BackgroundEffect.blurRegion`; keep separate visible, input, and blur regions. The compositor/API owns unsupported-protocol behavior (warning or no-op), while `glass` retains the readable translucent fallback. Never add a second interactive window or a broad unsafe blur override.
5. Keep Wi-Fi `Connect` blue, make secondary `Forget` neutral, and reserve Tokyo City red for `Confirm forget`; preserve semantic orange for muted/warning states.
6. Make Audio `Mute`/`Unmute` controls icon-only with stable hit targets and channel-specific accessible names or themed tooltip feedback.
7. Synchronize DESIGN.md and AGENTS.md with the actual current window architecture and global surface contract.
8. Run Qt6 lint, config parsing, diff checks, reload verification, visual capture review, protocol capability checks, and native review; record evidence and leave delivery uncommitted pending explicit user authorization.

## Non-goals
- No service, audio, network, routing, focus, Escape, mask, or multi-monitor logic changes.
- No new arbitrary hex colors.
- No root/window opacity used as a shortcut for background policy.
- No fullscreen blur workaround or broad compositor override that affects unrelated surfaces.

## Delivery evidence
- Baseline global surface styling committed as `acaa105` (`feat(quickshell): add global surface styling`).
- Native blur hooks are now uncommitted follow-up work; runtime protocol support and visual glass behavior remain pending live QA.
- Current working-tree glass test configuration intentionally remains `surface.mode: "glass"` with `surface.nativeBlur: true`; the shipped/default fallback contract remains solid/opaque when this test override is removed.
- Button saturation follow-up adds the `button.*` grammar: opaque darkened semantic fills with primary/secondary tone and hover/pressed lift tokens. It leaves cards, tracks, progress, services, routing, focus, and native blur ownership unchanged. The former `island.activeFillOpacity` and `island.powerTintOpacity` names are inert historical tokens; active and destructive action fills now follow `Theme.buttonFill()`.

## Acceptance criteria
- Shipped default is global `solid` with opacity `1.0` and readable opaque backgrounds.
- `translucent` and `glass` are discoverable global configuration options with safe validation and fallback.
- All eligible visual shells share one surface policy; neutral nested cards do not retain unrelated literal opacity values.
- Glass attempts native blur only when `surface.mode` is `glass` and `surface.nativeBlur` is true; each `GlassEffect` region contains only intended visible surface items, never transparent input/catcher regions or fullscreen masks. Unsupported compositor/API behavior warns or no-ops, preserving the readable translucent fallback without stealing input.
- Wi-Fi actions use blue Connect, neutral Forget, and red Confirm forget; all remain Tokyo City semantic roles.
- Mute buttons are icon-only with stable hit targets and neutral styling when unmuted; orange appears only for muted/warning state.
- Existing Tokyo City palette roles remain semantically separable.

## Implementation evidence

- `surface.nativeBlur` is shipped as `true` in `quickshell/.config/quickshell/config.json`; `Theme.qml` validates it as a boolean and the QML hooks additionally require `surface.mode === "glass"`.
- `Bar.qml`, `MprisPopup.qml`, `MetricsDropdown.qml`, and `LauncherCentered.qml` attach the installed `BackgroundEffect.blurRegion` API to bounded `GlassEffect` regions; `notifications/Notifications.qml` attaches it to a bounded `Region` covering `toastColumn`. Regions contain visible cards/sections only; transparent surface margins, fullscreen masks, and input catchers are not included.
- The native API owns unsupported-protocol behavior (warning or no-op). The existing translucent `glass` fills remain in place as the readable fallback, and `solid`/`translucent` never attach blur regions.
- Validation: Qt 6.11 `qmllint` completed on all touched QML files with only documented pre-existing/API warnings; `python -m json.tool` accepted `config.json`; `git diff --check` passed.
