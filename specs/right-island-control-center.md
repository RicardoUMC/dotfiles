# Spec: Right Island Control Center

## Status

Planned / Requirements discovery

## Purpose

The right bar island should become the shell's primary system-control entry point: compact in the bar, rich when opened. It should combine quick status, device controls, notifications, and advanced but well-organized device metrics while preserving the shell's clean Tokyo City visual language.

## Product Direction

### Role

The right island is a **hybrid control center**:

- Compact bar state: concise status and affordances.
- Expanded state: system controls, notification controls, audio/network/device management, and styled metrics.

This separates shell responsibilities:

- **Center island**: current activity and lightweight dashboard, especially media/productivity.
- **Right island**: system control, environment state, and device telemetry.

### Visual Target

The first target is a **right-aligned floating dropdown** anchored to the right island. A later phase may explore a richer **right sidebar** for deeper workflows.

The panel should be adaptive:

- Simple by default.
- Detailed when sections are expanded or selected.
- Dense enough to be useful, but organized enough to avoid visual fatigue.
- Density should support presets plus fine-grained token tuning: compact, normal, and comfortable presets can set sensible groups of spacing/card sizes, while advanced users can tune structural tokens directly.
- Responsive behavior should be prepared architecturally, but the first implementation may target the current 1920x1080 workflow with fixed defaults. Avoid layout assumptions that would block adaptive widths/heights later.

Inspirations:

- **Ambxst / Ax-Shell**: modular panels, expandable dashboards, composable controls, polished animations.
- **Dank Material Shell**: visual cohesion, hierarchy, restraint, and consistent spacing/typography.

## Included Capabilities

The right island/control center should eventually cover:

- Wi-Fi status and connection management.
- Bluetooth status and device management.
- Audio output/input selection and volume/mute controls.
- Notification state, recent notifications, mute, and do-not-disturb controls.
- Device metrics beyond raw values: compact styled graphs, histories, and grouped summaries.
- Temperatures where available.
- Network throughput, active interface, and IP details.
- Disk usage and I/O.
- Battery/energy information if relevant, even though the current machine is desktop-first.
- Power profile / performance mode.
- Night light / color temperature.
- Screenshot / recording controls.
- VPN as a secondary capability.

Explicitly out of scope for this panel:

- System update management.
- Hyprland control surface / compositor settings.
- Custom quick actions / arbitrary user shortcuts for now. If the project later becomes a broader Arch Linux shell and users request this, revisit it as a separate community-driven feature.

## Primary Controls

The top-priority controls are:

1. Wi-Fi.
2. Bluetooth.
3. Audio.

These three controls define the first interaction-design pass. The first design exploration should intentionally prototype one different interaction model per primary control so Ricardo can compare them in real use before choosing the final standard:

- **Wi-Fi**: inline expander inside the dropdown. The user can reveal nearby networks without leaving the main control-center context.
- **Bluetooth**: nested/detail pane inside the same floating surface. Device discovery, pairing, and connected-device state can test a clearer focused state.
- **Audio**: separate dialog or secondary panel. Output/input routing, volume, mute state, and per-device controls can test a focused secondary surface.

Default primary-control order is Wi-Fi, Bluetooth, audio. Reordering primary controls is not required in the first version, but the model should avoid blocking it later.

These assignments are exploratory, not final product commitments. After visual/interaction validation, the project should decide whether to keep mixed patterns or converge on one preferred model.

## Metrics Placement

Device metrics should be visible in the control center, but brief, summarized, and visually quiet by default. They should support a quick system-health read without distracting from Wi-Fi, Bluetooth, and audio.

Initial direction:

- Show compact summaries in the first viewport when space allows.
- Prefer three concise first-viewport signals: CPU/load, RAM, and current network throughput.
- Format first-viewport metrics as a compact horizontal row of values with small sparklines, keeping telemetry visually quiet compared to the primary controls.
- Clicking the metrics row should expand inline within the control center to show additional metrics such as GPU, disk, and temperatures where available.
- Reserve GPU, disk, temperatures, and longer histories for the expanded metrics section or later sidebar mode.
- Keep metrics visually organized as telemetry, not the main command surface.

## System Integration Strategy

Wi-Fi, Bluetooth, and audio should be exposed to UI components through service abstractions rather than direct command calls inside visual components.

Preferred direction:

- Build UI and backend behavior in parallel for critical paths, so the first prototype feels real rather than purely decorative.
- Long-term: DBus/native service integrations where practical, because they are structured, reactive, and closer to a real shell architecture.
- First implementation: CLI-backed services are acceptable when they unblock prototyping, but only behind clean abstractions that can later migrate to DBus without rewriting UI components.
- UI components should consume service properties and methods such as state, device lists, scanning/connecting flags, and connect/disconnect actions.
- Avoid parsing command output directly inside visual QML components.

Critical first-pass integrations:

- Wi-Fi: current connection state, available networks, scan/loading state, and connect/disconnect entry points.
- Bluetooth: adapter on/off state, connected devices, available devices, and connect/disconnect entry points.
- Audio: current output/input devices, volume/mute state, and output/input selection entry points.
- Notifications: current sound/DND state and recent notification previews if available from the existing notification system.
- Metrics: CPU, RAM, and network throughput summaries using existing `SystemStats` data where possible.

Non-critical capabilities such as VPN, night light, recording controls, temperatures, disk detail, and advanced histories may be recommended and shaped during implementation instead of fully specified upfront.

Candidate backend paths:

- Wi-Fi: NetworkManager via DBus long-term; `nmcli` acceptable behind a service abstraction for first prototype.
- Bluetooth: BlueZ via DBus long-term; `bluetoothctl` acceptable behind a service abstraction for first prototype.
- Audio: PipeWire/WirePlumber integration long-term; `wpctl` acceptable behind a service abstraction for first prototype.

Service organization:

- Use small domain services for backend ownership, such as `WifiService`, `BluetoothService`, and `AudioService`.
- Add a right-panel/control-center aggregator when the panel needs one coordinated source for ordering, visibility, summary state, and cross-domain presentation.
- Initial aggregator role: state coordinator. It should compose domain-service state into panel-friendly summaries such as connected network, Bluetooth activity, muted audio, notification state, and compact metrics.
- Adaptive visual policy, such as deciding which status rises in collapsed adaptive mode, can be added later when adaptive mode is implemented.
- Avoid one large monolithic system-controls service as the primary backend boundary.

## Future Settings GUI Integration

From the beginning, new right-island controls should be designed as future Settings GUI citizens:

- Visibility/order should eventually be configurable.
- Structural values should use `Theme.qml`/`config.json` tokens where appropriate.
- Control-specific preferences should avoid hardcoded one-off state when a settings panel will need to expose them later.
- This does not mean building the Settings GUI first; it means avoiding design choices that block it.

## Animation Model

Control-center opening/closing animation should be configurable rather than hardcoded to one motion style.

Supported animation-style targets:

- Fade + small vertical slide from the island.
- Scale from the anchor point + fade.
- Slide from the right.
- Minimal / near-instant.

Default animation style: slide from the right.

Each style should eventually expose independent parameters through config and later Settings GUI, such as duration, easing, distance, scale origin/intensity, opacity curve, and reduced-motion behavior. The animation config should support a global default plus per-overlay overrides, so the control center, launcher, power menu, and future panels can differ when useful without duplicating the motion model. The first implementation may support a smaller subset, but should avoid baking motion constants directly into components.

## Overlay Model

The existing centralized overlay coordination in `shell.qml` should remain the authority. The desired model can be described as a contextual tree/graph:

- Opening an incompatible primary panel closes the previous primary panel.
- Child panels can exist under their parent context.
- Closing a parent closes all descendants.
- The right control center and the center dashboard should be mutually exclusive: opening one should close the other because they are competing system focus surfaces.
- Hover never opens, closes, or replaces panels.
- Explicit user actions drive panel transitions.
- A short delay before opening remains useful to avoid Wayland serial conflicts.

For implementation, this does not require changing to a literal tree data structure immediately. The current context-group model may be extended with parent/child metadata when nested control-center panels require it.

## Collapsed Right Island

The compact right-island state should support two design modes:

- **Icon access mode**: compact icons for key entry points. Default visible icons should be Wi-Fi, Bluetooth, audio, notifications, and power.
- **Adaptive status mode**: shows the most relevant current state with a strict visual limit, avoiding noisy always-visible telemetry.
- **Power action**: power remains visually separated at the end of the right island and continues to open the existing PowerMenu directly. It should remain separate from the control center long-term; a future visual redesign may refine the power affordance based on design-skill feedback, but its direct-action role should remain distinct from daily control-center interactions.

The user should eventually be able to choose between these modes and configure visible compact icons through configuration and later the Settings GUI. The first implementation may choose one default, but should avoid hardcoding assumptions that prevent the other.

Adaptive status priority should eventually be configurable. Default priority should surface problems first, such as disconnected Wi-Fi, muted/failed audio, Bluetooth errors, or other actionable system issues. Activity and notification prioritization can be configured later.

## Wi-Fi

Wi-Fi uses the inline expander prototype inside the right dropdown. Expanded Wi-Fi should show a bounded list of nearby networks without letting the dropdown become visually dominated by scan results.

Initial direction:

- Collapsed Wi-Fi card shows icon, current SSID or disconnected label, signal strength, and connection state.
- Collapsed Wi-Fi card uses two interaction zones while Wi-Fi is on: the main/left zone toggles Wi-Fi off directly, while the right chevron zone expands/collapses the network list.
- Make the split interaction visually clear enough to avoid confusing the Wi-Fi power action with expansion.
- When Wi-Fi is off, the whole card should simply communicate `Wi-Fi off`; it should not show the network-list affordance or expand into an empty list. The available action is turning Wi-Fi back on from the card.
- When Wi-Fi is on but not connected, show `Searching…` while scanning and `Not connected` when idle.
- When Wi-Fi is connected, show SSID, signal strength, and a small `Connected` state label if it fits cleanly.
- Use an available-height-aware maximum with a strict cap.
- Default visible network count: 5.
- Sort expanded networks with the connected network first, known/saved networks next, and remaining networks by signal strength.
- Each available network row should show SSID/name, signal strength, security indicator, and known/saved state where available.
- Network rows can be clickable for connection; reserve explicit action buttons for cases where clarity, accessibility, or password entry requires them.
- Clicking a saved/known network should show a compact detail or confirmation state before connecting, rather than immediately switching networks.
- Saved-network confirmation should show SSID, signal strength, security, known/saved state, and actions for `Connect` and `Forget`.
- `Forget` must always require confirmation before removing a saved network.
- For a secured unknown network, show password entry inline within the expanded Wi-Fi area rather than opening a separate dialog.
- Inline password entry should be compact, clearly associated with the selected network, and easy to cancel without collapsing the full Wi-Fi section.
- Additional networks require scroll or a `More` affordance.
- Hidden SSID / `Join hidden network` is out of scope for the first version.
- The collapsed Wi-Fi control should show connection state clearly before expansion.

## Bluetooth

Bluetooth uses the nested/detail-pane prototype inside the same floating surface. The detail pane should provide enough focus for connected devices, available devices, and pairing flows without crowding the main dropdown.

Initial direction:

- Collapsed Bluetooth card shows icon, primary connected device name, and connected-device count when more than one device is connected.
- Collapsed Bluetooth card follows the same split interaction model as Wi-Fi while Bluetooth is on: the main/left zone toggles Bluetooth off directly, while the right chevron zone enters the Bluetooth detail pane.
- Collapsed fallback states: `No devices` when Bluetooth is on with no connected devices, and `Bluetooth off` when the adapter is off.
- When Bluetooth is off, the whole card should communicate `Bluetooth off`; it should not show the detail-pane affordance. The available action is turning Bluetooth back on from the card.
- Separate devices into `Connected` and `Available` sections.
- Device rows show name, connection/pairing state, device-type icon where available, and battery level where available.
- Keep always-visible actions minimal. Selecting a connected device expands its row inline with `Disconnect` and `Forget` actions instead of immediately disconnecting or navigating to a separate device detail view.
- `Forget` must always require confirmation before removing a Bluetooth device.
- For available devices, known/paired devices may connect directly, while new/unpaired devices should expand with a `Pair` action before starting pairing.
- Pairing state should show `Pairing…`, a spinner/progress affordance, and clear error/retry feedback if pairing fails.
- Discovery/scanning state should appear as a small state within the `Available` section rather than dominating the pane.
- Empty available-device state should show `Searching for devices…` while scanning and `No devices found` when idle.
- If devices are connected, prioritize `Connected` visually.
- If no devices are connected, let `Available` take visual priority.
- Pair/connect/disconnect actions should be clear but not visually louder than device identity and state.

## Audio

Audio uses the separate dialog or secondary-panel prototype. The first version should prioritize output and input control without trying to become a full mixer immediately.

Initial direction:

- Collapsed audio card shows icon, current output device, volume level, and mute state.
- Collapsed audio card uses a small explicit mute/unmute button; the rest of the card opens the focused audio panel. Avoid making the entire card a mute toggle.
- First version: output + input/mic with equal importance.
- Audio panel layout should use stacked blocks that feel visually equivalent rather than tabs or cramped columns.
- Output and input device rows should show device name, type/icon where available, active/default state, and level where available.
- Clicking an output or input device row switches to that device immediately. The active/default row must be visually clear enough to make the immediate-selection behavior understandable.
- The audio panel should remain open after switching devices so the user can confirm the change and adjust volume/gain.
- First version should include output volume, input gain, and mute controls for both output and input.
- Live level meters are not required in the first version.
- Output test sound and mic test are out of scope for the first version; revisit later only if they add clear value.
- Future direction: mini mixer with output, input, active apps, and per-app live levels.
- The audio surface should be focused enough for routing decisions and volume/mute state.
- Preferred first placement: a focused floating panel aligned to the right and spatially related to the right island.
- Avoid overloading the main right dropdown with all audio device details.

## Notifications

The compact notification icon should open a notification mini panel rather than only toggling mute. The mini panel should combine:

- Recent notification list or preview.
- Available-height-aware recent notification count, defaulting to 3 visible notifications.
- Default grouping: chronological list without grouping.
- Future configuration may enable app grouping or smart grouping, but the first version should remain simple.
- Separate sound mute control: notifications still arrive but do not play sound.
- Separate do-not-disturb control: stronger interruption control distinct from sound mute.
- Provide both a global `Clear all` affordance and per-notification dismiss affordances.
- Clear/dismiss affordances where appropriate.

The notification surface should stay smaller than the full control center and should not compete with Wi-Fi, Bluetooth, and audio as the primary daily controls.

## First-Phase Shape

Initial panel target:

- Right-aligned dropdown anchored to the right island.
- Default panel width: 420px.
- Width should be configurable through `config.json` and later Settings GUI.
- Default panel maximum height: approximately 600px or 60% of the screen, with internal scrolling when content exceeds it.
- Maximum height should be configurable through `config.json` and later Settings GUI.
- Mixed visual structure: primary controls use card-like modules, while metrics and secondary controls can use quieter rows or integrated blocks.
- Primary cards should be sober by default and become more expressive when active, connected, muted, disconnected, or otherwise stateful. Use a light combination of single-side/accent border and very subtle background tint; avoid strong glow or permanently loud tiles.
- Domain color defaults should stay cohesive: use the shell accent by default, with domain-specific colors only for meaningful states. Future configuration should not be arbitrary free-form color picking; choices should be constrained to the active colorscheme palette/tokens so user customization remains theme-consistent.
- Color semantics should combine domain identity and global state semantics: Wi-Fi, Bluetooth, and audio may use palette-constrained domain accents, while warning/error/success/offline states should use global semantic tokens consistently.
- Future Settings GUI should support both quick color-style presets and advanced per-domain token selection. This is not required for the first control-center implementation, but the model should not block it.
- Default hierarchy: primary controls first, metrics second, notification mini panel and secondary toggles last.
- Future configurability: users should eventually be able to choose/reorder section order. The first implementation should prefer a config-backed structure, then the future Settings GUI should edit that same structure rather than introducing a separate model.
- Preferred config shape: a list of section objects, e.g. `rightPanel.sections: [{ "id": "primaryControls", "visible": true }, { "id": "metrics", "visible": true }, { "id": "secondaryToggles", "visible": true }]`. This supports ordering, visibility toggles, and future per-section options without a parallel Settings GUI model.
- Quick toggles near the top by default.
- Metrics area with compact graphs and grouped summaries, visually secondary to the primary controls.
- Existing `MetricsDropdown`/metrics button may remain temporarily during migration. Once the new control center has sufficient compact metrics, metrics should be integrated into the control center and the dedicated metrics entry can be retired or repurposed.
- Secondary toggles such as VPN, recording, night light, and power profile are out of scope for the first version.
- Visual density: adaptive, with simple defaults and expanded detail on demand.

## Open Questions

1. Which compact metrics are worth showing in the first viewport without making the panel noisy?
2. Should the later sidebar replace the dropdown or coexist as an expanded/deep mode?
3. For the audio secondary surface, should it be a small focused dialog, a larger mixer panel, or a sidebar candidate?
4. For Bluetooth detail view, which states are essential in the first version: connected devices, available devices, battery levels, pair/unpair, trust/block?
