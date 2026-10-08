# Global configurable opacity and glass surfaces

## Goal
Make opacity and Glassmorphism a global visual-surface system for the bar/islands, center dashboard, right control center, launcher, notifications, MPRIS, metrics dropdowns, and their neutral nested cards. Preserve backend behavior, routing, focus, Escape, multi-monitor ownership, input masks, and the Tokyo City semantic palette.

## Tasks
1. Define and document the global configuration contract for `surface.mode` (`solid`, `translucent`, `glass`), global opacity defaults, role-specific surface alphas, validation, and fallback behavior. The shipped default remains `solid` with opacity `1.0`.
2. Add a small Theme surface grammar that applies policy to backgrounds only; keep text, icons, controls, artwork, semantic accents, urgency, selection, hover/press states, progress, and debug masks independent.
3. Apply the shared surface grammar to bar/islands, center dashboard, right control center, launcher, notification toasts, MPRIS, metrics dropdowns, and neutral nested cards without changing their ownership or input/focus behavior.
4. Implement compositor-backed blur for the shared visual surfaces using Quickshell's native `BackgroundEffect.blurRegion` when the running compositor advertises the protocol; keep separate visible, input, and blur regions. Otherwise provide an explicit readable translucent fallback for `glass` and document the limitation. Never add a second interactive window or a broad unsafe blur override.
5. Keep Wi-Fi `Connect` blue, make secondary `Forget` neutral, and reserve Tokyo City red for `Confirm forget`; preserve semantic orange for muted/warning states.
6. Make Audio `Mute`/`Unmute` controls icon-only with stable hit targets and channel-specific accessible names or themed tooltip feedback.
7. Synchronize DESIGN.md and AGENTS.md with the actual current window architecture and global surface contract.
8. Run Qt6 lint, config parsing, diff checks, reload verification, visual capture review, protocol capability checks, and native review; record evidence and leave delivery uncommitted pending explicit user authorization.

## Non-goals
- No service, audio, network, routing, focus, Escape, mask, or multi-monitor logic changes.
- No new arbitrary hex colors.
- No root/window opacity used as a shortcut for background policy.
- No fullscreen blur workaround or broad compositor override that affects unrelated surfaces.

## Acceptance criteria
- Shipped default is global `solid` with opacity `1.0` and readable opaque backgrounds.
- `translucent` and `glass` are discoverable global configuration options with safe validation and fallback.
- All eligible visual shells share one surface policy; neutral nested cards do not retain unrelated literal opacity values.
- Glass does not blur transparent input/catcher regions or steal input; if real blur cannot be scoped, the fallback is explicitly documented.
- Wi-Fi actions use blue Connect, neutral Forget, and red Confirm forget; all remain Tokyo City semantic roles.
- Mute buttons are icon-only with stable hit targets and neutral styling when unmuted; orange appears only for muted/warning state.
- Existing Tokyo City palette roles remain semantically separable.
