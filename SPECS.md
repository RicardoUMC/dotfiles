# SPECS.md — Tokyo City Shell

Behavioral specifications for all components and systems.
This document is the source of truth for **what the system must do** — not how it's implemented.

For visual decisions and design principles, see `DESIGN.md`.
For agent/developer workflow, see `AGENTS.md`.

---

## Index

| Spec | Status | Description |
|------|--------|-------------|
| [Bar](specs/bar.md) | Implemented | Top bar, floating islands |
| [Workspaces](specs/workspaces.md) | Implemented | Workspace indicator with app names |
| [System Stats](specs/system-stats.md) | Implemented | CPU, RAM, GPU, disk, network, volume, clock |
| [MPRIS](specs/mpris.md) | Implemented | Music indicator chip and popup player |
| [Notifications](specs/notifications.md) | Implemented | Toast notifications with sounds |
| [Launcher](specs/launcher.md) | Implemented | App launcher overlay |
| [Power Menu](specs/power-menu.md) | Implemented | Power/session overlay |
| [Lock Screen](specs/lock-screen.md) | Implemented | hyprlock-based lock screen |
| [Theme System](specs/theme-system.md) | Implemented | Mutable design tokens + config.json |
| [Settings GUI](specs/settings-gui.md) | Planned | Visual configuration panel |
| [Calendar](specs/calendar.md) | Planned | Calendar popup from clock |
| [OSD](specs/osd.md) | Planned | Volume/brightness overlay |
| [Overlay Manager](specs/overlay-manager.md) | Planned | Centralized overlay focus system |
