# Multi-Monitor

**Status:** In Progress (code complete; open gaps are visual confirmation plus one documented screen-intent limitation)
**Files:** `quickshell/.config/quickshell/shell.qml`, `bar/Bar.qml`, `bar/Workspaces.qml`, `launcher/LauncherCentered.qml`, `osd/OsdWindow.qml`, `notifications/Notifications.qml`, `theme/Theme.qml`, `config.json`

## Description

Shell behavior across an arbitrary number of monitors. The shell runs as **one Quickshell process** for the whole compositor session and creates **one surface instance per screen**; it never spawns a process per monitor.

Two rules dominate this spec:

- **N-monitor generic** — never assume a monitor count, an index, or a stable ordering.
- **One engine, many views** — stateful side-effect engines exist exactly once; per-screen UI consumes shared state.

## Verified environment

Reported by `hyprctl monitors` on this machine:

| Output | Description              | Resolution  | Position | Scale | Focused |
| ------ | ------------------------ | ----------- | -------- | ----- | ------- |
| `DP-1` | Xiaomi Corporation Mi... | 2560x1440   | 1920x0   | 1     | yes     |
| `DP-2` | Microstep MAG 244F       | 1920x1080   | 0x320    | 1     | no      |

Environment facts, not limits. A third monitor must work without code changes. Note the layout is deliberately awkward — the 2560-wide display sits to the **right** of the 1920-wide one, and the two differ in height — so nothing may infer ordering, adjacency, or a shared origin.

## Verified API surface (Quickshell 0.3.1)

Confirmed against the installed QML type info, not from memory:

| API                                        | Provides                                                      |
| ------------------------------------------ | ------------------------------------------------------------- |
| `Quickshell.screens`                       | reactive list of `ShellScreen` (`screensChanged`)             |
| `ShellScreen`                              | `name`, `model`, `serialNumber`, `x`, `y`, `width`, `height`  |
| `PanelWindow.screen`                       | read/write screen binding — the mechanism for per-screen UI   |
| `Variants`                                 | `model` / `delegate` / `instances` — multi-instance primitive |
| `Hyprland.monitorFor(screen)`              | `HyprlandMonitor` for a given `ShellScreen`                    |
| `HyprlandMonitor`                          | `id`, `name`, `description`, geometry, `scale`, `focused`, `activeWorkspace` |
| `HyprlandWorkspace.monitor`                | owning monitor of a workspace                                 |
| `Hyprland.workspaces`                      | **global** model — spans every monitor                        |
| `Hyprland.focusedMonitor`                  | the monitor holding focus — input for launcher/OSD targeting  |
| `Hyprland.refreshMonitors()`               | re-read of monitor state, including each monitor's active workspace |
| `UntypedObjectModel.values`                | array view of a model, notified by `valuesChanged`            |

### Screen targeting is explicit

A `PanelWindow` is an independent layer-shell surface. It does **not** inherit the screen of whatever window or component declares it. Verified in the installed Quickshell source:

- `setScreen(nullptr)` sets `compositorPicksScreen = true`, which is also the default (`wayland/wlr_layershell/wlr_layershell.cpp:129`, `wlr_layershell.hpp:188`).
- The `wl_output` is only resolved when that flag is false; otherwise `nullptr` is handed to `get_layer_surface`, meaning "compositor picks" (`wayland/wlr_layershell/surface.cpp:143`).
- `qscreen()` falls back `window->screen()` → explicit `mScreen` → `primaryScreen`, with no parent lookup (`window/proxywindow.cpp:428`).

Consequence: **every** surface that must appear on a specific monitor binds `screen` explicitly. Nesting a `PanelWindow` inside a screen-bound item is not enough — a per-screen Bar propagates its own screen down into each overlay it owns. Leaving a surface unpinned is only ever correct when the compositor's choice is acceptable.

A second consequence governs *when* a screen may be written: `ProxyWindowBase::setScreen` unmaps and re-maps a surface whose output changes while it is mapped. Surfaces that re-point themselves therefore write the screen only while unmapped, immediately before being shown.

## Per-surface convention

Placement and layer are decided together: the layer a surface is born in fixes whether it can be covered by another shell surface, and the screen fixes where it appears. Layer values below are the `WlrLayershell.layer` each surface declares; the policy and its protocol reasoning are in `specs/overlay-manager.md`.

| Surface                      | Placement                                             | Layer | Rationale                                                    |
| ---------------------------- | ----------------------------------------------------- | ----- | ------------------------------------------------------------ |
| Bar                          | one instance per enabled screen                       | `Top` | each monitor needs its own status and entry points           |
| Workspace island             | one per bar, **filtered to its own monitor**          | `Top` (inside the bar surface) | `Hyprland.workspaces` is global; unfiltered mixes monitors   |
| Right control center         | on the screen whose icon opened it                    | `Top` | the action belongs where the user clicked                    |
| Power menu                   | on the screen whose icon opened it                    | `Top` | same                                                         |
| MPRIS popup, center catcher, metrics dropdown | on the screen whose bar owns them (`screenTarget: root.screen`) | `Top` | the overlay belongs to the bar that opened it |
| Launcher                     | focused screen                                        | `Top` | opened by IPC/keys, not by a per-screen click                |
| Notification toasts          | per screen                                            | `Overlay` | alerts should not be hidden behind an unfocused monitor, and must never sit under a shell panel |
| OSD (volume/brightness)      | focused screen                                        | `Overlay` | reflects input to the active display, above every panel |
| Center dashboard             | inside its own bar instance                           | `Top` (inside the bar surface) | expansion is local to the bar that hosts it                   |

## Overlay model: global exclusivity

Overlay exclusivity is **global across screens**, not per-screen: at most one overlay is open in the whole session, and it renders on the screen that requested it.

Consequences the implementation honors:

- `overlayManager` state is a single `activeOverlay` plus a single `activeScreenName`.
- Opening an overlay on `DP-2` closes any overlay open on `DP-1`.
- Routing resolves a target Bar instance by screen identity through `barForScreen(name)`; every open command, close command, and bar-geometry read goes through it.
- The 50 ms anti-serial-conflict timer is shared and stays single — global exclusivity means there is never more than one pending open.
- Bar signals are connected **per delegate instance** in the `Variants` delegate, so every event carries its own `barInstance.screenName`. Bar instances never talk to each other.
- Click-outside, `Escape`, and workspace-change dismissal keep working on whichever screen holds the overlay.

There are no context groups in this model. See `specs/overlay-manager.md`.

## Bar instantiation

`shell.qml` builds the enabled-screen list in a `QtObject { id: screenSelector }` and instantiates Bar through `Variants`:

- `enabledScreens` reads `Quickshell.screens` and `Theme.barScreens` and resolves by `ShellScreen.name` only — never by index or ordering.
- Unmatched names are ignored. If the resolved set is **empty** — a named monitor was unplugged, or a name was typo'd — it **falls back to all screens** rather than leaving the session without a bar.
- The binding re-evaluates on `screensChanged`, so hot-plug adds and removes bar instances without a reload.
- The delegate is `Bar { required property ShellScreen modelData; screen: modelData; screenName: modelData.name }`.
- Each instance also receives `hyprlandMonitor`, `notificationsState`, `systemStatsState`, and `workspaceMonitorTick` from the shell root. `hyprlandMonitor` is resolved by reading `Hyprland.monitors.values` as a dependency before calling `Hyprland.monitorFor(modelData)`, because `monitorFor()` is a plain invokable that emits nothing: Quickshell can publish a screen before Hyprland publishes its monitors (startup) or replace one during a hot-plug, and a bare call would stick at `null`.
- `pragma ComponentBehavior: Bound` at the top of `shell.qml` is what makes the delegate's capture of `root`, `overlayManager`, `notifications`, and `systemStats` legal; it matches how Quickshell instantiates `Variants` delegates, with the delegate component's own creation context.

## Workspace island: per-monitor view

`bar/Workspaces.qml` renders a filtered view of the global workspace model. It receives its monitor by injection and never probes the compositor itself.

- **Membership:** iterate `Hyprland.workspaces.values`, keep workspaces whose `ws.monitor.name` equals this instance's monitor name. Identity is matched by **name**, never by index or ordering.
- **Null monitor:** the island renders no chips rather than throwing and taking the whole bar instance down with it — the startup and hot-plug window where a screen exists before its monitor resolves.
- **Active state comes from this monitor's own `activeWorkspace`, not from `Hyprland.focusedMonitor`.** Acting on a background monitor must light that monitor's chip, not whichever monitor holds focus. The comparison uses the workspace **name**, with `""` as the "nothing active / monitor not resolved yet" sentinel — an id would be unsafe because named workspaces can legitimately have negative ids.
- **Invalidation:** `Hyprland.workspaces` notifies `valuesChanged` on insert and remove, but moving a workspace between monitors mutates `HyprlandWorkspace.monitor` silently. One `workspaceMonitorTick` counter, owned in `shell.qml` and bumped on the `moveworkspace` / `moveworkspacev2` raw events, is the single external invalidation signal; it is injected down through `Bar` into the island. No bar instance listens to the compositor for this itself.
- A `moveworkspace` event also changes what each monitor is showing, and no event carries the monitor identity needed to repoint every monitor's `activeWorkspace`, so the same shell-level handler calls `Hyprland.refreshMonitors()` (Quickshell dedupes overlapping refresh requests internally).
- **Special workspaces:** the `activespecial` payload is `"<specialName>,<monitorName>"`. Both outputs can name their special the same way (`special:magic`), so the island stores the owner monitor and matches on **name and owning monitor** together. Without the monitor field, both bars would light the same special. Closing a special reports an empty name for that monitor.

## Launcher and OSD: focused-screen policy

Both surfaces are triggered by IPC or a keybind rather than by a click on a specific monitor, so they resolve their own output: match `Hyprland.focusedMonitor.name` against `ShellScreen.name`, never by list index and never assuming a monitor count.

- The resolved screen lands in a plain `property ShellScreen targetScreen` that `screen` reads; it is written **imperatively**, not by binding `screen` to focus state.
- The write happens **only while the surface is unmapped**, immediately before it is shown, because `setScreen()` on a mapped surface unmaps and rebuilds it. This matters most for the OSD, which is re-triggered by repeated media-key presses: a pill already on screen keeps the screen it appeared on rather than being torn down under the user.
- If focus cannot be matched — no focused monitor yet, or a hot-plug race with no `ShellScreen` for the focused monitor — the previous pin is kept, so the surface can neither throw nor vanish.
- `shell.qml` reads `launcher.targetScreen` to choose the Bar instance whose geometry it consults for outside-click routing, so the launcher defers to the bar on the screen it actually covers.

## Engine ownership

The following are instantiated **exactly once per session**, in `shell.qml` (or as a non-surface engine root):

- `SystemStats` — 1 s CPU/RAM/GPU/disk/network probe plus a `wpctl` volume read.
- Hyprland toplevel-refresh orchestration — the startup refresh and the `openwindow` / `closewindow` / `movewindow` handler that calls `Hyprland.refreshToplevels()`.
- `workspaceMonitorTick` — the single workspace-move invalidation owner.
- `Notifications` — the `NotificationServer`, sound player, both models, both persistence layers, and DND/mute state. Only the toast surface is duplicated, one `PanelWindow` per screen via `Variants`. See `specs/notifications.md`.
- Every `IpcHandler`.

`WifiService`, `BluetoothService`, and `AudioService` are `pragma Singleton` and are therefore already safe from per-screen duplication.

Per-screen UI may duplicate **views** (islands, masks, cards, toast surfaces) but never **probes, IPC handlers, notification servers, or compositor-refresh drivers**.

## Configuration

`bar.screens` selects which monitors get a bar:

| Value                | Meaning                                        |
| -------------------- | ---------------------------------------------- |
| `"all"` (default)    | one bar on every connected screen              |
| `[ "DP-1", ... ]`    | only the named screens                         |

Semantics are described under [Bar instantiation](#bar-instantiation): name-only resolution, unmatched names ignored, empty result falls back to all screens, reactive on `screensChanged`. Currently `config.json` sets `"all"`.

## Current implementation status

Statuses are per `SPECS.md` rules: `Implemented` requires both code and verification.

| Piece | State |
| --- | --- |
| Per-screen `Bar` via `Variants` + `screen: modelData` | **Implemented** — code in `shell.qml`; two bar surfaces observed on the live compositor, one per output, each sized to its own monitor |
| `bar.screens` config (`"all"` or name array) with empty-set fallback to all screens | **Implemented** — code in `Theme.qml` / `config.json` / `shell.qml` |
| Global overlay exclusivity keyed by `(activeOverlay, activeScreenName)`, all routing through `barForScreen()` | **Implemented** — code in `shell.qml` |
| Per-instance signal routing carrying `barInstance.screenName` | **Implemented** — inline handlers in the `Variants` delegate |
| Bar-owned overlays pin to their bar's screen (`screenTarget: root.screen` → inner `PanelWindow.screen`, all five surfaces) | **Implemented in code.** Observed: the power-menu overlay covered `DP-1` at exactly `1920 0 2560 1440` while `DP-2` held focus. Honest caveat — this rules out *"follows the focused monitor"*, and is consistent with pinning, but an unpinned surface is free to land anywhere the compositor chooses, so the observation is supporting rather than conclusive proof. Conclusive read: open the same overlay from a right-island click on `DP-2` and confirm it appears there. |
| Workspace filtering per monitor, by name identity | **Implemented in code**; chip-by-chip visual read of both islands is the open gap |
| Special-workspace match on owner monitor | **Implemented in code**; visual confirmation pending |
| `workspaceMonitorTick` single owner + `refreshMonitors()` on workspace moves | **Implemented** — code in `shell.qml` |
| Launcher screen policy (focused monitor, written while unmapped) | **Implemented** — observed moving with focus: opened full-screen on `DP-1` while `DP-1` was focused, then on `DP-2` (`0 320 1920 1080`) while `DP-2` was focused |
| Notifications: one engine, per-screen toast surfaces | **Implemented** — observed two toast surfaces for one notification, one per output, both at real height |
| OSD screen policy (focused monitor) | **Implemented** — observed on the bottom of `DP-2` while `DP-2` was focused, then `DP-1` after focus moved |
| IPC/keybind-triggered **bar** overlays resolving to the focused screen | **Not implemented, by documented fallback** — see Limitations |

## Limitations and open gaps

- **IPC-triggered bar overlays use the first-instance fallback.** `launcher toggle` and `powermenu toggle` pass an empty screen identity, and `barForScreen("")` returns the first available instance. Observed directly: with `DP-2` focused, `quickshell ipc call powermenu toggle` opened the power menu on `DP-1`. Bar geometry reads for that path (`powerBtnGlobalX`, `mprisChipGlobalX`) also come from the first instance. The launcher is unaffected once open because it resolves its own screen; the power menu is not. Focused-screen resolution for IPC-triggered bar overlays is the intended follow-up.
- **The `launcher` slot is not screen-attributed.** The manager records an empty `activeScreenName` for it (`onDismissed: overlayManager.close("", "launcher")`) even though the surface itself is pinned. Harmless under one global slot, but the manager cannot say which screen the launcher was on.
- **Visual confirmation remains for the workspace islands.** Code and compositor data agree (`hyprctl workspaces -j` reports workspace `2` on `DP-1`, `1` on `DP-2`, and each island filters by exactly that identity), but no command can prove what each bar *paints*. The specific reads still owed by Ricardo:
  1. The left island on each monitor lists **only** that monitor's workspaces — no `2` chip on `DP-2`, no `1` chip on `DP-1`.
  2. Working on the unfocused monitor lights **that** monitor's chip, not the focused one's.
  3. A special workspace opened on one monitor does not light the same-named special on the other.
  4. Moving a workspace between monitors updates **both** islands without a reload.
  5. A right-island overlay opened by clicking on the **unfocused** monitor appears on that monitor, not on the other one — the conclusive check for `screenTarget` pinning, which the IPC-triggered observation only supports.
- **Hot-plug has not been exercised.** Every reactive path (bar add/remove, toast surface add/remove, `hyprlandMonitor` re-resolution, screen-name fallback) is reasoned from the bindings, not observed with a cable pulled.
- `closeAll()` is screen-agnostic about *which* monitor triggered the compositor event; it does not need to know, because there is only one overlay slot.

## Known reactivity limits

`Hyprland.workspaces` exposes a `values` array notified by `valuesChanged`, which covers insert and remove. Moving a workspace between monitors mutates `HyprlandWorkspace.monitor` without changing the list, so a monitor-filtered model can go stale until the next insert/remove. Filtering therefore invalidates on the shell-owned `workspaceMonitorTick` bumped by the `moveworkspace` event. This is a solved problem, recorded because it is invisible in the code at the point of use and easy to regress.

## Non-goals

- Per-monitor independent overlay state — rejected in favor of global exclusivity, so a second monitor's overlay click cannot leave two panels open at once.
- Cross-screen drag of shell surfaces — not a Quickshell shell responsibility.
- Per-monitor scale compensation of fixed pixel tokens — both current monitors run scale 1; revisit with a mixed-DPI setup as a token-scaling decision, not an ad-hoc per-screen multiplier.
- Placing different surfaces on hard-coded monitor names in QML.
