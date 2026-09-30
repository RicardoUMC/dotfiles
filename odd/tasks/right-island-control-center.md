:# right-island-control-center

## Goal
Implement the Quickshell right-island control center: a hybrid system-control surface anchored to the right bar island, with real UI and backend behavior for Wi-Fi, Bluetooth, audio, notifications, and compact metrics.

## Tasks

- [x] 1. Implement base structure
  - Create `RightControlCenter.qml` as the main dropdown/panel.
  - Create/update right-island entry point in `Bar.qml` or a dedicated component.
  - Register new QML types in `bar/qmldir` and/or root `qmldir`.
  - Integrate overlay coordination into `shell.qml` (open/close signals, mutual exclusion with center dashboard).
  - Apply initial structural tokens from `Theme.qml`.

- [x] 2. Implement backend service abstractions
  - `services/WifiService.qml`: state, scan, connect, disconnect, forget, password handling.
  - `services/BluetoothService.qml`: adapter state, connected devices, available devices, pair, connect, disconnect, forget.
  - `services/AudioService.qml`: output/input devices, volume, mute, selection.
  - Register service types in `qmldir` if they are local QML files.
  - First implementation may use CLI (`nmcli`, `bluetoothctl`, `wpctl`) behind these abstractions.

- [x] 3. Implement Wi-Fi UI
  - Collapsed card with split toggle/expand zones.
  - Expanded inline list with sorting (connected, known, by signal).
  - Network rows with SSID, signal, security, known state.
  - Saved-network confirmation with Connect/Forget.
  - Inline password entry for new secured networks.
  - Empty/off states.

- [x] 4. Implement Bluetooth UI
  - Collapsed card with split toggle/detail zones.
  - Detail pane with Connected and Available sections.
  - Device rows with name, state, type/icon, battery.
  - Inline row expansion for connected devices (Disconnect/Forget).
  - Pair flow for new devices with loading/error/retry.
  - Empty/off/scanning states.

- [x] 5. Implement Audio UI
  - Collapsed card with mute button and panel opener.
  - Secondary floating audio panel aligned to the right island.
  - Stacked output and input blocks.
  - Device rows with name, type/icon, active state, level.
  - Immediate device selection.
  - Volume/gain sliders and mute toggles.

- [x] 6. Implement Notifications mini panel
  - Compact notification icon in right island.
  - Mini panel with recent notifications (default 3, height-aware).
  - Separate sound-mute and do-not-disturb controls.
  - Clear all and per-notification dismiss.
  - Chronological list; grouping configurable later.

- [x] 7. Implement compact metrics
  - Horizontal row of CPU, RAM, network values with sparklines.
  - Inline expansion for GPU, disk, temperature details.
  - Use existing `SystemStats` data where possible.

- [x] 8. Correct interaction architecture and compact entry points
  - Make the compact right island expose the defined icon-access mode by default while preserving separated power.
  - Make Wi-Fi remain the inline expander prototype.
  - Make Bluetooth a real nested/detail-pane prototype rather than a visually identical inline expander.
  - Make Audio a visually distinct secondary surface prototype.

- [x] 9. Apply unified visual polish
  - Reduce nested cards, visible padding, borders, and repeated rectangular containers.
  - Preserve mixed hierarchy: primary controls, quiet notification/metrics sections.
  - Keep state accents restrained and palette-token based.

- [ ] 10. Complete configurable/detail behavior
  - Add right-panel structural tokens/config where safe.
  - Add Wi-Fi overflow behavior (`More`/scroll) and height-aware bounds.
  - Add Bluetooth pairing progress/retry feedback.
  - Refine notification mini-panel and metrics details.

- [ ] 11. Verification
  - `qmllint quickshell/.config/quickshell/**/*.qml` passes or pre-existing failures are documented.
  - Manual visual verification of layout, open/close, exclusivity, collapsed/expanded states.
  - No token sprawl; structural values use `Theme.qml`/`config.json`.

- [ ] 12. Documentation sync
  - Update `AGENTS.md`, `DESIGN.md`, and `specs/right-island-control-center.md` if implementation diverges from spec.
  - Update `odd/tasks/right-island-control-center.md` evidence.

## Evidence

- Slice 1 base structure implemented by worker:
  - `quickshell/.config/quickshell/bar/RightControlCenter.qml`
  - `quickshell/.config/quickshell/bar/Bar.qml`
  - `quickshell/.config/quickshell/shell.qml`
  - `quickshell/.config/quickshell/bar/qmldir`
- Focused lint passed: `qmllint quickshell/.config/quickshell/shell.qml quickshell/.config/quickshell/bar/Bar.qml quickshell/.config/quickshell/bar/RightControlCenter.qml`.
- Full/glob lint still needs final run; worker reported the glob command failed with no diagnostics, likely existing/tooling behavior.
- Backend CLI research:
  - Wi-Fi: `nmcli` available; useful commands include `nmcli -f SSID,SIGNAL,SECURITY,ACTIVE dev wifi list --rescan no`, `nmcli connection show --active`, `nmcli device status`, `nmcli -t -f NAME,UUID,TYPE,DEVICE connection show`.
  - Bluetooth: `bluetoothctl` available; useful commands include `bluetoothctl show`, `bluetoothctl devices`, `bluetoothctl devices Paired`, `bluetoothctl devices Connected`, `bluetoothctl info <MAC>`.
  - Audio: `wpctl` and `pactl` available; useful commands include `wpctl status`, `wpctl list audio sinks`, `wpctl list audio sources`, `wpctl inspect <ID>`, `wpctl get-volume @DEFAULT_AUDIO_SINK@`, `wpctl get-volume @DEFAULT_AUDIO_SOURCE@`, `wpctl set-default`, `wpctl set-volume`, and `wpctl set-mute`.
- Slice 2 service abstractions implemented by worker:
  - `quickshell/.config/quickshell/services/qmldir`
  - `quickshell/.config/quickshell/services/WifiService.qml`
  - `quickshell/.config/quickshell/services/BluetoothService.qml`
  - `quickshell/.config/quickshell/services/AudioService.qml`
- Service lint passed: `qmllint quickshell/.config/quickshell/services/*.qml`.
- Slice 3 Wi-Fi UI implemented by worker:
  - `quickshell/.config/quickshell/bar/WifiControlCard.qml`
  - `quickshell/.config/quickshell/bar/RightControlCenter.qml`
  - `quickshell/.config/quickshell/bar/qmldir`
- Fixed optional-chaining expressions in `WifiControlCard.qml` because `qmlformat`/`qmllint` failed with exit 255 and no diagnostics.
- Wi-Fi focused lint now passes: `qmllint quickshell/.config/quickshell/bar/WifiControlCard.qml quickshell/.config/quickshell/bar/RightControlCenter.qml`.
- Slice 4 Bluetooth UI implemented by worker:
  - `quickshell/.config/quickshell/bar/BluetoothControlCard.qml`
  - `quickshell/.config/quickshell/bar/RightControlCenter.qml`
  - `quickshell/.config/quickshell/bar/qmldir`
- Bluetooth focused lint passed: `qmllint quickshell/.config/quickshell/bar/BluetoothControlCard.qml quickshell/.config/quickshell/bar/RightControlCenter.qml`.
- Slice 5 Audio UI implemented by worker:
  - `quickshell/.config/quickshell/bar/AudioControlCard.qml`
  - `quickshell/.config/quickshell/bar/AudioControlPanel.qml`
  - `quickshell/.config/quickshell/bar/RightControlCenter.qml`
  - `quickshell/.config/quickshell/bar/qmldir`
- Audio focused lint passed: `qmllint quickshell/.config/quickshell/bar/AudioControlCard.qml quickshell/.config/quickshell/bar/AudioControlPanel.qml quickshell/.config/quickshell/bar/RightControlCenter.qml`.
- Audio secondary panel is an in-control-center stacked surface for now, not a separate `PanelWindow`, to avoid risky overlay coordination changes in this slice.
- Slice 6 Notifications mini panel implemented by worker:
  - `quickshell/.config/quickshell/notifications/Notifications.qml`
  - `quickshell/.config/quickshell/bar/NotificationControlCard.qml`
  - `quickshell/.config/quickshell/bar/RightControlCenter.qml`
  - `quickshell/.config/quickshell/bar/Bar.qml`
  - `quickshell/.config/quickshell/shell.qml`
  - `quickshell/.config/quickshell/bar/qmldir`
- Verified only one `NotificationServer` exists and the existing `Notifications` instance is passed through `shell.qml -> Bar.qml -> RightControlCenter.qml -> NotificationControlCard.qml`.
- Notifications focused lint passed: `qmllint quickshell/.config/quickshell/notifications/Notifications.qml quickshell/.config/quickshell/bar/NotificationControlCard.qml quickshell/.config/quickshell/bar/RightControlCenter.qml quickshell/.config/quickshell/bar/Bar.qml quickshell/.config/quickshell/shell.qml`.
- Slice 7 Metrics UI implemented by worker:
  - `quickshell/.config/quickshell/bar/MetricsControlCard.qml`
  - `quickshell/.config/quickshell/bar/SystemStats.qml`
  - `quickshell/.config/quickshell/bar/RightControlCenter.qml`
  - `quickshell/.config/quickshell/bar/Bar.qml`
  - `quickshell/.config/quickshell/bar/qmldir`
- `SystemStats.qml` now exposes `netInterface`, `netRx`, `netTx`, and `netHistory` from default-route interface counters.
- Metrics focused lint passed: `qmllint quickshell/.config/quickshell/bar/MetricsControlCard.qml quickshell/.config/quickshell/bar/RightControlCenter.qml quickshell/.config/quickshell/bar/Bar.qml quickshell/.config/quickshell/bar/SystemStats.qml`.
- Focused lint over every touched QML file passed:
  - `shell.qml`
  - `bar/Bar.qml`
  - `bar/RightControlCenter.qml`
  - `bar/WifiControlCard.qml`
  - `bar/BluetoothControlCard.qml`
  - `bar/AudioControlCard.qml`
  - `bar/AudioControlPanel.qml`
  - `bar/NotificationControlCard.qml`
  - `bar/MetricsControlCard.qml`
  - `bar/SystemStats.qml`
  - `notifications/Notifications.qml`
  - `services/WifiService.qml`
  - `services/BluetoothService.qml`
  - `services/AudioService.qml`
- Full `qmllint quickshell/.config/quickshell/**/*.qml` still exits 255 with no diagnostics due pre-existing files: `CenterDashboard.qml`, `MetricsDropdown.qml`, `MetricsPane.qml`, `MprisIndicator.qml`, `MprisPopup.qml`, `Workspaces.qml`, `Theme.qml`.
- Correction Slice A implemented by worker:
  - Added `RightIslandIconButton.qml` and separate compact Wi-Fi/Bluetooth/Audio/Notifications entries while keeping Metrics and Power separate.
  - Converted Bluetooth expanded state to a focused in-surface detail view with Back affordance.
  - Added distinct Audio secondary-surface header/back treatment.
  - Focused lint passed for all changed QML files in the slice.
- Visual polish Slice B implemented by worker:
  - Unified outer-panel rhythm and reduced header/margin spacing.
  - Softened primary shells, detail surfaces, notification rows, and metrics blocks.
  - Removed most repeated borders while preserving state accents and interaction targets.
  - Focused lint passed for all seven polished QML files plus the broader touched-file set.
- Corrected localized NetworkManager active-state parsing in `services/WifiService.qml` to recognize `yes`, `sí`, `si`, `true`, and `1`.
- Increased global configurable font defaults in `config.json` first to `11/12/14/16/20`, then to the current larger scale caption/label/body/bodyLg/icon `12/13/15/17/22`; `Theme.qml` applies these tokens globally.
- Validation passed: Wi-Fi service lint, config JSON parse, and boolean parsing check.
- Added configurable `Theme.rightPanelOpacity` with `rightPanel.opacity` config key, default `0.94`, and bound the outer control-center surface to it. Internal surfaces remain subtly translucent.
- Right-panel binding lint and config JSON validation passed; Theme.qml retains the pre-existing qmllint exit-255/no-diagnostic issue.
- Typography/chip geometry update applied in `Theme.qml` and `config.json`: font scale `12/13/15/17/22`, `barChipHeight` `30`.
- Config JSON validation passed; runtime visual validation remains required to confirm no clipping or excessive bar growth.
- Deep-link routing correction implemented:
  - compact Wi-Fi/Bluetooth/Audio/Notifications icons request section-specific routes;
  - `RightControlCenter.openSection()` activates only the requested area;
  - MetricsButton removed from compact right island while MetricsControlCard remains inside the panel;
  - focused routing lint passed.
- Specialty-surface correction implemented:
  - section mode now shows only the selected Wi-Fi, Bluetooth, Audio, or Notifications content;
  - Wi-Fi/Bluetooth standalone mode removes the left-side power-toggle interaction and redundant chevron affordance;
  - Audio/Notifications open their expanded specialty content directly;
  - focused specialty-panel lint passed.
- Specialty panel height now derives from `contentColumn.implicitHeight + margins`, capped at `600px`, while preserving the aggregate minimum; this removes large empty vertical space in short Wi-Fi views.
- Refined project-local design skills:
  - `visual-critic` now enforces composition-first critique, expressive minimalism, layered surfaces, density, and evidence-vs-taste separation;
  - `interaction-designer` now requires visual composition for each interaction state and explicitly rejects generic sparse/flat design;
  - `visual-critic` now decomposes supplied references into reusable visual grammar and acts as a seasoned art director, balancing modern touches against trend-chasing and gratuitous decoration.
