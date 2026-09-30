# Workspaces

**Status:** Implemented
**File:** `quickshell/.config/quickshell/bar/Workspaces.qml`

Per-monitor architecture — screen identity, bar instantiation, and the ownership of compositor-refresh signals — is specified in `specs/multi-monitor.md`. This file specifies the workspace island itself.

## Description
Workspace indicator showing workspace number/icon and active app names. Each `Bar` instance owns one island and renders **only its own monitor's** workspaces; `Hyprland.workspaces` is a global model, so an unfiltered island would mix monitors.

## Behavior

### Injection, not probing
- `Bar.qml` passes its own `hyprlandMonitor` into the island as `monitor` and forwards `workspaceMonitorTick`. The island never resolves a screen or drives a compositor refresh itself.
- A **null monitor** — the startup or hot-plug window before Quickshell registers the output — renders **no chips** rather than throwing and taking the whole bar instance down with it.

### Per-monitor membership
- The view iterates `Hyprland.workspaces.values` and keeps the workspaces whose `ws.monitor.name` equals this instance's monitor name. A workspace with no resolved monitor is skipped.
- Identity is matched by monitor **name** only — never by index, never by list order, never by a monitor count.

### Active state
- Active state comes from **this monitor's own `activeWorkspace`**, compared by workspace name. It previously came from `Hyprland.focusedMonitor`, which lit the wrong chip whenever work happened on an unfocused monitor.
- The empty string is the "nothing active / monitor not resolved yet" sentinel. An id would be unsafe as a sentinel, because named workspaces can legitimately have negative ids.
- Special workspaces are matched on **name and owning monitor** together: the `activespecial` payload is `"<specialName>,<monitorName>"`, and both outputs can name their special the same way (`special:magic`). Without the monitor field, two bars would light the same special. An empty name in the payload means the special just closed on that monitor.
- A normal workspace that is this monitor's active one while a special is open on the same monitor is exposed as `isUnderSpecial`. The state is declared and correct; no distinct visual treatment reads it yet.

### Invalidation
- `Hyprland.workspaces` notifies `valuesChanged` on insert and remove only. **Moving a workspace between monitors mutates `HyprlandWorkspace.monitor` silently**, so a monitor-filtered view would go stale until the next insert or remove.
- One `workspaceMonitorTick` counter, owned by `shell.qml`, is the external invalidation signal. It is bumped in the shell's single existing `Connections { target: Hyprland }` on `moveworkspace` **and** `moveworkspacev2`, and the same branch calls `Hyprland.refreshMonitors()` — a move also changes what each monitor shows, and no event carries the monitor identity needed to repoint every monitor's `activeWorkspace` (Quickshell dedupes overlapping refresh requests internally).
- The tick is injected down through `Bar` into the island. No bar instance listens to the compositor for this itself.
- Per-app labels come from each workspace's own `toplevels` model, so toplevel refreshes are visible without the island requesting any.

### Display format
- Each workspace shows: `[number/icon] · [app1] | [app2]`
- Special workspace (`special:magic`) shows icon `󰓪`; any other `special:` prefix shows `󰎔`
- Active workspace: text is bright + bold, tinted with `Colors.cyan` for a special and `Colors.accent` for a normal workspace
- Inactive workspace: text is muted
- Chip height is `Theme.barChipHeight`, corner radius `Theme.radiusSm`, spacing `Theme.spacingXs`

### App name resolution
1. Look up app class in `DesktopEntries.applications` by ID (case-insensitive)
2. If found, use the desktop entry `name`
3. Fallback: strip reverse-DNS prefix (last segment) or suffixes `-browser`, `-desktop`
4. Capitalize first letter

### Separator
- `•` between workspace number and app list (only visible when workspace has open windows)
- `|` between multiple apps (only visible for index > 0)

## Not implemented
- **No click-to-activate.** The chips are indicators: the island declares no `MouseArea`/`TapHandler` and dispatches no Hyprland workspace request. Switching workspaces is a compositor keybinding, not a bar interaction.

## Verification state
- **Verified in code and compositor data:** the per-monitor filter matches exactly what `hyprctl workspaces -j` reports for each output, and the active-state source is the monitor's own `activeWorkspace`.
- **Not verified — visual read owed by Ricardo:** no command can prove which chips each bar *paints*. The four specific island checks (per-monitor chip lists, the unfocused monitor's active chip, per-monitor special highlight, both islands updating after a cross-monitor move) are listed in `specs/multi-monitor.md` and still pending.
- **Not verified:** hot-plug behavior of the island. The null-monitor path is reasoned from the bindings, not observed with a cable pulled.
