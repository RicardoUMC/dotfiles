# SPECS.md — Tokyo City Shell

Behavioral specifications for all components and systems.
This document is the source of truth for **what the system must do** — not how it's implemented.

For visual decisions and design principles, see `DESIGN.md`.
For agent/developer workflow, see `AGENTS.md`.

---

## Index

| Spec                                        | Status        | Description                                                                 |
| ------------------------------------------- | ------------- | --------------------------------------------------------------------------- |
| [Bar](specs/bar.md)                         | Implemented   | Per-screen top bar, floating islands, in-place center dashboard             |
| [Configurable Bar](specs/configurable-bar.md) | Planned     | Future per-monitor position, visibility, style, and dashboard attachment    |
| [Workspaces](specs/workspaces.md)           | Implemented   | Per-monitor workspace chips with app names                                  |
| [System Stats](specs/system-stats.md)       | Implemented   | CPU, RAM, GPU, disk, network, volume, clock                                 |
| [MPRIS](specs/mpris.md)                     | Implemented   | Music indicator chip and popup player                                       |
| [Notifications](specs/notifications.md)     | Implemented   | One engine, per-screen toasts, retained + persisted history                 |
| [Launcher](specs/launcher.md)               | Implemented   | App launcher overlay on the focused monitor                                 |
| [Power Menu](specs/power-menu.md)           | Implemented   | Power/session overlay                                                       |
| [Lock Screen](specs/lock-screen.md)         | Implemented   | hyprlock-based lock screen                                                  |
| [Theme System](specs/theme-system.md)       | Implemented   | Mutable design tokens + config.json + `Motion` intent primitive             |
| [Settings GUI](specs/settings-gui.md)       | Planned       | Visual configuration panel                                                  |
| [Right Island Control Center](specs/right-island-control-center.md) | In Progress | Right-island system controls and metrics              |
| [Calendar](specs/calendar.md)               | Planned       | Calendar popup from clock                                                   |
| [OSD](specs/osd.md)                         | Implemented   | Volume/brightness overlay on the focused monitor                            |
| [Overlay Manager](specs/overlay-manager.md) | Implemented   | Single-slot global overlay exclusivity, logical interaction paths, and per-screen routing |
| [Multi-Monitor](specs/multi-monitor.md)     | In Progress   | N-monitor surfaces, global overlay, per-screen bar, screen targeting        |

---

## Status notes

Status values are defined by the `sync-docs` contract: `Planned`, `In Progress`, `Implemented`, `Deprecated`. `Implemented` requires both code and verification.

- **Configurable Bar is `Planned`.** `specs/configurable-bar.md` captures the future design for global defaults with per-monitor overrides, four positions, independent visibility, external-edge reveal boundaries, island/continuous styles, and embedded/detached dashboard attachment. None of those future configuration keys or behaviors are implemented yet.
- **Multi-Monitor is `In Progress` on confirmation, not on code.** Per-screen bars, per-screen toast surfaces, bar-owned overlay screen pinning, launcher/OSD focused-monitor targeting, per-monitor workspace filtering, and single-slot global overlay exclusivity are all implemented and observed on the live compositor. Two things remain open, named in `specs/multi-monitor.md`: the visual read of each workspace island (four specific checks Ricardo owes), and focused-screen resolution for IPC-triggered **bar** overlays, which still resolve through the documented first-instance fallback.
- **Overlay Manager is `Implemented`** as one global slot plus per-instance routing and logical interaction paths. Same paths toggle, sibling paths switch locally, descendants remain within their parent surface, and unrelated roots use global close-then-open routing. The `bar-primary` / `bar-secondary` context-group model that older docs described was never implemented; the specs now describe the single-slot behavior that exists.
- **Workspaces stays `Implemented`.** The chip feature itself renders and is verified; the per-monitor filter is correct in code and in compositor data, and the pending per-island visual read is tracked under Multi-Monitor's open gaps rather than by downgrading this row twice.
- **OSD keeps `Brightness` in its description.** Panel brightness is reachable on this host through `ddcutil` (DDC/CI) via `hyprland/.config/hypr/scripts/brightness`, which resolves the focused connector, applies the value, and reports the applied percentage to the OSD through `quickshell ipc call osd showBrightness`. `/sys/class/backlight` is empty here, so the earlier `brightnessctl` binding never touched a panel. Volume and brightness both now produce an OSD pill.
- **Launcher is `Implemented`** including focused-monitor targeting, observed live: the same IPC trigger filled `DP-1` while `DP-1` was focused and `DP-2` (`0 320 1920 1080`) while `DP-2` was focused.
- **No row is `Deprecated`.** The only intentional removal this round was `bar/MetricsButton.qml`, which was never an index row — it is a right-island entry point recorded inside `specs/bar.md` and `specs/overlay-manager.md`. `MetricsDropdown.qml` remains on disk as deliberately dormant infrastructure.
- **Right Island Control Center stays `In Progress` on confirmation, not on code.** The services, specialty cards, host, and deep-linking icons were already unverified on the live compositor; the Caelestia-inspired right-island visual pass (state-layer chips, semantic divider, power pill) and the scoped `Motion` pilot are now implemented, Qt 6.11 lint-clean, and validated by offscreen runtime probes — but live visual confirmation and a debug-off screenshot are still pending. Do not read the lint/probe evidence as user-visible success.
- **Theme System keeps `Implemented`.** The token/hot-reload contract is implemented and verified; the newer `Motion` singleton is lint-clean and offscreen-probed, and its live-compositor animation behavior is tracked as an open confirmation item under the Right Island row and in `odd/tasks/caelestia-right-island.md` rather than by downgrading this row.
