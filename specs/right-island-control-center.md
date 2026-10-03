# Spec: Right Island Control Center

## Status

In Progress

Implemented and lint-verified: `services/` Wi-Fi, Bluetooth and Audio singletons; the specialty cards (`WifiControlCard`, `BluetoothControlCard`, `AudioControlCard`/`AudioControlPanel`, `NotificationControlCard`, `MetricsControlCard`); the `RightControlCenter` host with per-section specialty routing; and compact right-island icons. The radio/adapter power switch in the two radio heroes and the group-header overflow reveals are implemented in the cards described below.

The Caelestia-inspired right-island visual pass is also implemented: the fill/shape/state-layer chip grammar (`StateLayer.qml` + rebuilt `RightIslandIconButton.qml`), the disabled-vs-active precedence, the configurable semantic divider, the distinct power pill, and the scoped `Motion` pilot (`theme/Motion.qml`, control-center body height, chip fill, and state-layer transitions). It is verified by Qt 6.11 lint and offscreen runtime probes; **live compositor visual confirmation and a debug-off screenshot are still pending**, so this remains `In Progress` rather than `Implemented`. Feature document: `odd/tasks/caelestia-right-island.md`.

## Purpose

The right bar island is the shell's primary system-control entry point: compact status in the bar, with each icon opening **its own specialty surface** rather than routing through a shared aggregate panel. It combines quick status, device controls, notifications, and organized device metrics while preserving the shell's Tokyo City visual language.

The aggregate control center remains implemented as the neutral landing composition (no section selected), but the compact icons deep-link to a single specialty surface; see [Collapsed Right Island](#collapsed-right-island) for the routing and [Multi-Monitor](multi-monitor.md) for placement.

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
- **Caelestia** (`caelestia-dots/shell`, kept outside the repo): the right-island visual pass adapts its **state-layer principle** (interaction state as flat fill, never border) and its **intent-named motion principle** (effects vs. spatial, no per-call-site easing literals). Inspiration only — no copied code, no Material-3 palette or curve table, no SDF/blob shader, no hover-open behavior; the Tokyo City palette and the single-slot overlay architecture are preserved. Rationale and rejected adaptations: `DESIGN.md`.

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

Current state: the scoped motion pilot is implemented. `theme/Motion.qml` provides named `Effects` / `EffectsColor` / `Spatial` intents driven by `Theme.anim*` and one global `anim.scale` multiplier, applied so far to the right island and control center only (`StateLayer` opacity, chip fill color, `panelBody` height). Panel-window open/close animation styles and per-overlay overrides remain unimplemented; `PanelWindow.visible` has no exit animation because the overlay manager tears the surface down synchronously. Unmigrated call sites elsewhere in the shell still use `Theme.anim*` directly by design. Contract: `specs/theme-system.md`.

## Overlay Model

The existing centralized overlay coordination in `shell.qml` remains the authority. What it actually does today is a **single global slot**: one `activeOverlay` plus one `activeScreenName`, so opening any overlay closes the active one on any screen, with the surface pinned to the screen that requested it.

That model already satisfies most of what a tree would provide here, because nested panels in the control center are **content inside one surface**, not separate overlays: the Bluetooth detail pane, the audio secondary panel, and the notification mini panel all live within `RightControlCenter.qml`. There is nothing to cascade — closing the control center removes its expanded section with it.

The requirements that remain true regardless of the model:

- The right control center and the center dashboard are mutually exclusive, because they are competing members of the one slot. Opening one closes the other. This is implemented.
- Hover never opens, closes, or replaces panels.
- Explicit user actions drive panel transitions.
- A short delay before opening remains useful to avoid Wayland serial conflicts — one shared 50 ms timer for the session, never one per bar instance.

**Logical interaction tree — implemented (lint-verified; live pointer confirmation pending):** the relationship-aware transitions among the control center's sections are now modeled as logical paths (`right-control-center`, `right-control-center/wifi`, `right-control-center/bluetooth`, `right-control-center/audio`, `right-control-center/notifications`). Same section on the same screen toggles closed; a different sibling section switches content in place without tearing down the root, losing screen ownership, or restarting the 50 ms timer. The descendant shape `right-control-center/audio/device-panel` is reserved in comments only — the current audio device panel remains content inside the `RightControlCenter` surface, not a routed node.

**Concurrent parent/child overlays remain explicitly out of scope.** There are no context groups in the codebase; the `bar-primary` / `bar-secondary` grouping that earlier revisions of this spec assumed was never implemented. If a future surface genuinely needs two overlays open at once, treat that as a change to the exclusivity rule rather than metadata on top of it. See `specs/overlay-manager.md` and `odd/tasks/interaction-tree-routing.md`.

## Collapsed Right Island

The compact right-island state should support two design modes:

- **Icon access mode**: compact icons for key entry points. Default visible icons should be Wi-Fi, Bluetooth, audio, notifications, and power. This is what ships: four fill/shape-grammar **service chips**, a configurable **semantic hairline** separating them from the power action (`island.separatorWidth`, `island.semanticGap`; width `0` removes line and gap together), and a **power pill** — same height, pill radius, resting red tint, red state layer — as the visually distinct direct action. Full collapsed-island behavior: [Collapsed Right Island](#collapsed-right-island); token contract: `specs/theme-system.md`.
- **Adaptive status mode**: shows the most relevant current state with a strict visual limit, avoiding noisy always-visible telemetry.
- **Power action**: power remains visually separated at the end of the right island and continues to open the existing PowerMenu directly. It should remain separate from the control center long-term; a future visual redesign may refine the power affordance based on design-skill feedback, but its direct-action role should remain distinct from daily control-center interactions. The current pass made that separation structural: the pill's shape and destructive tint, not a border, mark it as different from service chips.

The user should eventually be able to choose between these modes and configure visible compact icons through configuration and later the Settings GUI. The first implementation may choose one default, but should avoid hardcoding assumptions that prevent the other.

Compact icon entries should open independent specialty surfaces rather than requiring the full control center as a parent:

- Wi-Fi icon opens the standalone Wi-Fi panel with its inline network details.
- Bluetooth icon opens the standalone Bluetooth detail pane.
- Audio icon opens the standalone Audio secondary surface.
- Notifications icon opens the standalone notification mini panel.
- Power remains a direct PowerMenu action.
- Metrics should not have a dedicated compact-island icon; metrics remain available from a future aggregate surface and/or dashboard.

The aggregate control center may remain as a future composition surface, but compact island icons must not force users through it to reach everyday specialty controls.

Adaptive status priority should eventually be configurable. Default priority should surface problems first, such as disconnected Wi-Fi, muted/failed audio, Bluetooth errors, or other actionable system issues. Activity and notification prioritization can be configured later.

## Wi-Fi

Wi-Fi uses the inline expander prototype inside the right dropdown. Expanded Wi-Fi should show a bounded list of nearby networks without letting the dropdown become visually dominated by scan results.

Initial direction:

- Collapsed Wi-Fi card shows icon, current SSID or disconnected label, signal strength, and connection state. In the expanded panel the hero reorders this information as a state puck (glyph + signal), a status label (`Connected` / `Searching…` / `Not connected` / `Wi-Fi off`), a title, and a meta line.
- The collapsed Wi-Fi entry is a single interaction surface that opens the standalone Wi-Fi panel; it does not use a left-side power toggle.
- The previous split toggle/chevron interaction on the collapsed card is intentionally retired because it was not practical in use. The power affordance now lives inside the panel, which is what the earlier decision said should happen.
- The panel ships the radio power control. The hero's trailing edge carries the `WifiPowerSwitch` — a borderless power glyph over a thin accent rail (height `Theme.accentSeamWidth`), no border, no box, secondary to the network identity. It sits in the trailing slot that the chevron (`visible: !root.standalone && WifiService.wifiEnabled`) vacates in standalone mode, and the panel still has exactly one accent seam: the hero's state-colored left rail. While the radio is on, the switch is the module's power control; the chevron handles expansion separately.
- When Wi-Fi is off, the hero itself becomes the power action: the hero `MouseArea` routes to `requestPower(true)`, the meta line changes from a description to an instruction (`Select to turn Wi-Fi on`), the switch takes its emphasis weight (accent slab, widened rail, `Turn on` label, `Theme.radiusMd`), and the nearby-networks group stays hidden (`visible: root.expanded && WifiService.wifiEnabled`), so no disabled empty list or dead vertical space appears under the hero.
- In-flight: `WifiService.setWifiEnabled` has exactly one UI call site, the card's `requestPower()` funnel, which early-returns while `powerPending` is set, so repeat clicks cannot enqueue a second call. While pending, the rail becomes a sweeping accent slab, the meta line reads `Turning Wi-Fi on…` / `Turning Wi-Fi off…`, and the switch's `MouseArea` is disabled. A `Connections` handler on `WifiService.onWifiEnabledChanged` settles the pending state as soon as the reported state matches `powerPendingTarget` and stops the settle timer; the `powerSettleTimer` fallback (`Theme.animSlow * 30` = 15 s ≈ three 5 s service refresh cycles) clears the pending state if the change is never reported, so a failed `nmcli radio` cannot leave the affordance permanently frozen in a pending animation; a reported service error surfaces through the card's `errorMessage` line instead.
- When Wi-Fi is off, the panel communicates it on the hero itself — both title and status read `Wi-Fi off` — without expanding an empty network list.
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
- Overflow is a real group-header control, not a scroll guess: a borderless `WifiPillAction` next to `Scan` in the `Nearby networks` header toggles `showAllNetworks`. Preview 5 / expanded all, with labels `Show all N` and `Show top 5`. Lifecycle rules: [Group-level overflow reveal](#group-level-overflow-reveal).
- Hidden SSID / `Join hidden network` is out of scope for the first version.
- The collapsed Wi-Fi control should show connection state clearly before expansion.

## Bluetooth

Bluetooth uses the nested/detail-pane prototype inside the same floating surface. The detail pane should provide enough focus for connected devices, available devices, and pairing flows without crowding the main dropdown.

Initial direction:

- Collapsed Bluetooth card shows icon, primary connected device name, and connected-device count when more than one device is connected; in the expanded panel the hero shows the first connected device's name as title and `N Connected` as the status label.
- The collapsed Bluetooth entry is a single interaction surface that opens the standalone Bluetooth detail pane; it does not use a left-side power toggle.
- The previous split toggle/chevron interaction is intentionally retired because it was not practical in use. The power affordance now lives inside the panel, which is what the earlier decision said should happen.
- Collapsed fallback states: `No devices` when Bluetooth is on with no connected devices, and `Bluetooth off` when the adapter is off.
- When Bluetooth is off, the standalone panel communicates `Bluetooth off` without opening an empty device list; both device groups are `visible: root.expanded && BluetoothService.bluetoothEnabled`.
- The panel ships the adapter power control with the same grammar as Wi-Fi: a borderless `BtPowerSwitch` on the hero's trailing edge (the slot the chevron vacates in standalone mode), one accent seam per module; adapter off turns the hero itself into the enable action, with the instruction meta line `Turn Bluetooth on to manage devices`, accent puck and rail, and the device groups hidden. In-flight behavior is identical: `BluetoothService.setBluetoothEnabled` has exactly one UI call site, the `requestPower()` funnel, and `powerPending` drives the sweeping rail, the `Turning Bluetooth on…` meta line, the click-blocking disabled handler, the `onBluetoothEnabledChanged` settle, and the same `Theme.animSlow * 30` settle-timer fallback that prevents a permanently stuck pending state after a failed `bluetoothctl power`.
- Separate devices into `Connected` and `Available` sections. The `Connected devices` group is intentionally uncapped — its list is never truncated, so it carries no reveal control, only the `N active` count in its header.
- Available-device overflow is a group-header control: a borderless `BtPillAction` next to `Scan` in the `Available devices` header toggles `showAllDevices`. Preview 6 / expanded all, with labels `Show all N` and `Show top 6`. Lifecycle rules: [Group-level overflow reveal](#group-level-overflow-reveal).
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

- Recent notification list or preview: newest-first rows from the retained history, preview capped at `maxVisibleNotifications: 3`.
- Overflow is a group-header control: a `NotificationPillAction` — a new in-file borderless pill component matching the other cards' header vocabulary — sits in the `Recent` header, ordered before the destructive `Clear all` text, and toggles `showAllNotifications`. Preview 3 / expanded up to the 50-row store cap, with labels `Show all N` and `Show newest 3`. Lifecycle rules: [Group-level overflow reveal](#group-level-overflow-reveal).
- Default grouping: chronological list without grouping.
- Future configuration may enable app grouping or smart grouping, but the first version should remain simple.
- Separate sound mute control: notifications still arrive but do not play sound.
- Separate do-not-disturb control: stronger interruption control distinct from sound mute.
- Provide both a global `Clear all` affordance and per-notification dismiss affordances.
- Clear/dismiss affordances where appropriate.

The notification surface should stay smaller than the full control center and should not compete with Wi-Fi, Bluetooth, and audio as the primary daily controls.

## Group-level Overflow Reveal

The inert `+N more …` labels the first pass rendered under each truncated list are gone. Overflow is now a reversible view-mode control in each list's own group header, using that card's existing borderless pill vocabulary (`WifiPillAction`, `BtPillAction`, `NotificationPillAction`). Shared lifecycle rules, verified in all three cards:

- **The pill only exists while the list is truncated** (`visible: networksTruncated` / `devicesTruncated` / `notificationsTruncated`). A list that fits its preview shows no control at all.
- **The count appears in both directions**, so the label cannot lie: `Show all N` names the true total when collapsed, `Show top 5` / `Show top 6` / `Show newest 3` names the preview cap when expanded.
- **Collapsing clears the row selection** (Wi-Fi, Bluetooth): `onShowAllNetworksChanged` / `onShowAllDevicesChanged` call `clearSelection()` when the mode returns to preview, because a detail sheet for a row that is no longer rendered would describe a vanished row. The notification card has no row-selection sheet, so its collapse rule is the reset itself.
- **Closing the card resets to preview**: `onExpandedChanged` resets the reveal flag (and clears the selection on the radio cards), and `RightControlCenter.resetSections()` collapses every card on open, so a re-opened panel never resumes an unannounced full-list mode.
- **The mode auto-resets when the list shrinks back inside the preview**: `onNetworksTruncatedChanged` / `onDevicesTruncatedChanged` / `onNotificationCountChanged` drop the flag, so a later scan or discovery cannot silently resume a full-list view against a now-short list.
- **Known limitation:** the reveal control lives in the group header, which scrolls with the list inside `RightControlCenter`'s `Flickable`. When a long list is expanded, the header — and with it the collapse control — scrolls out of view, so collapsing requires scrolling back up. Accepted for now: keeping the control adjacent to the list it governs outweighs a sticky-header complication, and closing/reopening the card always returns to preview.

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
- Existing `MetricsDropdown` may remain available as an internal/fallback surface during migration, but the dedicated Metrics button should be removed from the compact right island. Metrics are integrated into the control center and can remain available from its expanded metrics row.
- Secondary toggles such as VPN, recording, night light, and power profile are out of scope for the first version.
- Visual density: adaptive, with simple defaults and expanded detail on demand.

## Open Questions

1. Which compact metrics are worth showing in the first viewport without making the panel noisy?
2. Should the later sidebar replace the dropdown or coexist as an expanded/deep mode?
3. For the audio secondary surface, should it be a small focused dialog, a larger mixer panel, or a sidebar candidate?
4. For Bluetooth detail view, which states are essential in the first version: connected devices, available devices, battery levels, pair/unpair, trust/block?
