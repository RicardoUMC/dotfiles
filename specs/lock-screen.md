# Lock Screen

**Status:** Implemented
**Files:** `hyprland/.config/hypr/hyprlock.conf`, `hyprland/.config/hypr/hyprland.conf`

> Note: the lock screen is implemented by **hyprlock** (the Hyprland native lock utility), not by Quickshell. The empty `quickshell/.config/quickshell/lockscreen/` directory holds no implementation and is not part of this spec.

## Description
Full-screen compositor lock driven by `hyprland/.config/hypr/hyprlock.conf`. A centered clock/date header sits above a password field, on a solid Tokyo City background, replicated across all monitors.

## Behavior

### Backend
- `hyprlock` is the locking backend, invoked as a plain `exec` process from a Hyprland keybind. No `general` rules beyond the two documented below are present in the config.
- Authentication uses hyprlock's default (PAM); the config declares no `auth` overrides.

### Invocation
- Triggered by **`$mainMod + Escape`** (`$mainMod = SUPER`), defined in `hyprland.conf` under a `# Lock screen` comment: `bind = $mainMod, Escape, exec, hyprlock`.
- Nothing in the Quickshell shell invokes or manages the lock — the bar and PowerMenu expose no lock action. Keybind is currently the only trigger.
- There is no automatic/idle locking configured in the tree.

### General
- `disable_loading_bar = true` — no loading indicator is shown while hyprlock initializes.
- `hide_cursor = true`.

### Display configuration
- Every element (`background`, both `label`s, `input-field`) sets `monitor =` (empty), which targets **all monitors** — the layout repeats independently on each screen rather than being pinned to one.
- All positioned elements use `halign = center` / `valign = center` with pixel offsets from the screen center, so the composition is resolution-agnostic.

### Background
- Solid color fill `rgba(171D23ff)` (base00, Tokyo City Terminal Dark background). There is **no wallpaper image**; the background is a flat opaque color.

### Clock and date labels
- Time label: shell command `cmd[update:1000] echo "$(date '+%H:%M')"` — refreshed every second, white (`rgba(ffffffff)`), 72 pt `SF Pro Display`, offset 120 px above center.
- Date label: `cmd[update:60000] echo "$(date '+%A, %d %B %Y')"` — refreshed every minute, 40 %-opacity white (`rgba(ffffff66)`), 18 pt `SF Pro Text`, offset 40 px above center.

### Password field (input indicator)
- `input-field`, 320×48, 1 px outline, positioned 60 px below center.
- Entry is shown as dots: `dots_size = 0.25`, `dots_spacing = 0.2`.
- Colors: outer `rgba(539AFCaa)` (accent, base0D), inner `rgba(1E2530ff)`, font white, `SF Pro Text`.
- `fade_on_empty = true`; placeholder text `contraseña...` in `#6B7280`.
- Feedback states: success `rgba(539AFCff)` (accent blue), failure `rgba(ff5555ff)` (red) with `fail_text` showing the failure message and attempt count; CapsLock warning color `rgba(f1fa8cff)`.
- `hide_input = false` (dot masking is handled by the dot indicators, not by the input mode flag).

## Gaps / current limitations
- No wallpaper image option (solid color only).
- No lock trigger from the shell UI (PowerMenu/bar); keybind only.
- No idle/auto-lock daemon configured.
- Lock appearance does not read `Theme.qml` / `config.json` tokens; its colors and fonts are hardcoded in `hyprlock.conf` (values currently match the Tokyo City palette and typography conventions).
