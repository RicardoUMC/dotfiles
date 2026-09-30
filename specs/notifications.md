# Notifications

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/notifications/Notifications.qml`, `NotificationToast.qml`, coordination in `quickshell/.config/quickshell/shell.qml`, consumer `bar/NotificationControlCard.qml`

## Description

Freedesktop notification receiver built as **one engine with N surfaces**. `Notifications.qml` is a non-surface `Item` that owns the only `NotificationServer`, the sound player, the DND/mute state, both list models, and both persistence layers — exactly once per session. Only the toast surface is duplicated: one `PanelWindow` per connected screen, via `Variants`.

The engine/surface split is a deliberate product decision, recorded here so it is not "simplified" back later: an alert must not be hidden behind an unfocused monitor, but a second server would double-deliver every notification and a second store would fork the history. State is therefore single, presentation is per screen. Same convention as the other shell-level singletons.

## Behavior

### Engine root

- `Item { id: root }` with `pragma ComponentBehavior: Bound` — not a `PanelWindow`. It declares no layer-shell surface, so it cannot be pinned, positioned, or mistakenly duplicated.
- Instantiated once in `shell.qml`: `Notifications { id: notifications }`. It takes no `screen` and no injected state; `shell.qml` hands the instance to every `Bar` as `notificationsState`, and each `Bar` passes it to `RightControlCenter` → `NotificationControlCard`.
- The only mutable notification state in the shell lives here: `soundMuted`, `doNotDisturb`, both models, both persistence layers.

### Two models: retention vs presentation

Retention and presentation are deliberately separate concerns with separate lifecycles.

| Model | Role | Holds | Bound |
|---|---|---|---|
| `historyModel` | the store | `{ notifId, summary, body, appName, urgency, timestamp }` — serializable values only | `maxHistoryEntries: 50` |
| `toastModel` | the transient surface | the same fields plus `timeout` and the live `notif` object | per-notification, expires |

- `property alias recentModel: historyModel` — `recentModel` stays the public name for the **store**, so the bar chip and the control center read retention, never live toasts.
- The store holds no notification objects, so nothing in it can go stale when the D-Bus message is retired. `notif` never leaves `toastModel`.
- **Toast expiry never removes a history row.** Only explicit dismissal (`✕`, invoking an action, `dismissAt` in the control center) or `Clear all` reduces the store.
- **DND genuinely retains.** `recordHistory(notif)` runs on every arrival *before* the toast is queued and independently of DND/mute, so a suppressed notification is stored rather than dropped. The control center's copy — "DND is on. New notifications will be collected silently." — now matches the code.
- Repeated id on arrival: the existing `toastModel` row is removed before the new row is appended (replacement on screen), and `recordHistory` **updates the matching store row in place** instead of appending a copy. Freedesktop reuses ids for progress reports and media metadata, so appending would evict real history under a flood of updates.
- Rows append to the end of the toast `ColumnLayout` (`spacing: Theme.spacingSm`), so the newest toast renders lowest in the stack.

### Eviction

- `trimHistory()` is `while (historyModel.count > maxHistoryEntries) remove(0)` — oldest first.
- The same bound applies to what reaches disk, because the snapshot is serialized from the store after trimming.

### Toast surface: one per screen

- `Variants { id: toastSurfaces; model: Quickshell.screens }`, delegate `PanelWindow { required property ShellScreen modelData; screen: modelData }`.
- Selection runs over `Quickshell.screens`, so a hot-plug adds or removes a surface with no reload and no assumption about monitor count or ordering.
- `screen` is bound explicitly per delegate because a layer-shell surface never inherits an output — see the "Screen targeting is explicit" section of `specs/multi-monitor.md`.
- Each surface: `WlrLayershell.layer: WlrLayer.Overlay`, `exclusionMode: ExclusionMode.Ignore`, `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`, anchors `top` + `right`, `margins { top: Theme.barHeight + Theme.spacingMd - 1; right: Theme.spacingMd - 1 }` — the same top-right offset as `PowerMenu.qml` and `RightControlCenter.qml`.
- `implicitWidth: 380`, `implicitHeight: toastColumn.implicitHeight`, so each surface grows and shrinks with its own stack. `NotificationToast` declares `implicitHeight: card.implicitHeight` for exactly this reason: without a measured height on the delegate, the surface collapses to 1 px and the toast renders invisibly.
- Surfaces are always visible and are **not** `overlayManager` overlays: they never take keyboard focus and are never closed by `closeAll()`. No `mask` region is declared, unlike `Bar.qml`'s union input mask.
- Delegates bind `visible: !root.doNotDisturb`, so DND hides toasts while reception continues into the shared model.
- The surfaces are pure views. No `NotificationServer`, sound player, `ListModel`, `PersistentProperties`, or `FileView` is duplicated inside the `Variants`.

### Shared rows, per-surface retirement

Every screen renders its own copy of the same `toastModel` row, so the same toast reports its end once per surface. Retiring therefore addresses the row by notification id, not by index:

- `closeToastById(notifId, explicit)` scans `toastModel` backwards and removes the first matching row. `explicit` (close button or action) also dismisses the live notification and calls `removeHistoryById`; a timeout only takes the toast off screen and leaves the record behind.
- A delegate whose id is no longer in the model simply finds nothing to close — that is how the second surface retires after the first one wins the race. Each copy runs its own countdown and hover clock, so which one fires first is not deterministic.

### Toast lifecycle

- Slide-in: `NumberAnimation on opacity { from: 0; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }`.
- Countdown is measured against **wall-clock time**, not a timer interval. State: `remainingMs`, `clockAnchor`, `clockPaused`, `clockFinished`, plus `remainingFraction` for the progress bar.
  - `elapsedSinceAnchor()` clamps to `Math.max(0, Math.min(remainingMs, Date.now() - clockAnchor))`, so a backward or forward clock adjustment can neither manufacture negative time nor skip more time than was left.
  - Hover **pauses and resumes the remainder** (`pauseClock()` folds elapsed time into `remainingMs`, `resumeClock()` re-anchors) rather than restarting the full timeout.
  - A user-resolved toast calls `stopClock()` on `dismissed`, freezing the countdown before the caller removes the delegate so no tick can fire in between.
- The tick is a repeating `Timer` at `clockTickInterval: 100`, deliberately *not* a `FrameAnimation`: this surface is an Overlay panel whose delegates are hidden whenever DND is on, and a frame-driven clock only advances while the scene graph renders. A `Timer` keeps suppressed toasts retiring on schedule so hidden delegates cannot pile up. Accuracy comes from the elapsed-time measurement, not from trusting the tick period.
- Timeout resolution: `notif.expireTimeout > 0 ? notif.expireTimeout : 5000` — `0` (app-requested "never expire") is overridden to a 5 s default.
- Progress bar: width `progressBar.width * root.remainingFraction`, with a `Behavior on width` animated at the tick interval so depletion reads as continuous motion between measured ticks. Urgency color at `0.6` alpha over a `2` px track.
- The card-level `MouseArea` sets `propagateComposedEvents: true` and `onClicked: mouse => mouse.accepted = false`, so clicks fall through to the action buttons and close glyph.

### Actions

- The actions row is visible only when `notif !== null && notif.actions.length > 0`; delegates come from the live `notif.actions` list, not from the stored row.
- Invoking an action calls `modelData.invoke()` then `dismissed()`, so the toast leaves the store as part of the action.

### Urgency rendering

- `Critical` → `Colors.red`, `Low` → `Colors.muted`, `Normal` (default) → `Colors.accent`. The resolved color drives the 1 px card border at `0.5` alpha and the depletion bar at `0.6` alpha.
- Card fill is `Colors.base01` at `Theme.opacitySurface`, radius `Theme.radiusMd`.
- App name, summary, and body use `Colors.uiFont` per the typography rule in `AGENTS.md`; `Colors.monoFont` is used only for the `✕` glyph, which is an icon.

### Urgency-to-sound mapping

- Single shared `Process { command: ["paplay", ""] }` reused per notification; `playSound()` rewrites the command array then sets `running = true`. It lives on the engine, so N surfaces cannot mean N sounds per notification.
- Base directory `/usr/share/sounds/freedesktop/stereo/`.
- `Critical` → `dialog-error.oga`, `Low` → `message-new-instant.oga`, everything else → `dialog-information.oga` — matches the `DESIGN.md` table.
- Sound is skipped entirely when `soundMuted` **or** `doNotDisturb` is true: DND silences without suppressing delivery.
- Because one `Process` node is reused, overlapping notifications are not represented by independent processes.

### Persistence

Two layers guard the store, and **exactly one of them hydrates it**. `historyRestored` is the one-restore-per-instance guard.

| Layer | Purpose | Survives |
|---|---|---|
| `PersistentProperties { reloadableId: "notificationHistory" }` | in-process reload handoff via `entries` | `Quickshell.reload()` |
| `FileView` at `Quickshell.statePath("notification-history.json")` | JSON snapshot of the store | process restart, reboot |

- **Precedence:** a non-empty reload handoff wins — it is the in-process truth and always at least as fresh as disk. The disk snapshot is consulted only when nothing was inherited, which is exactly the restart case. This ordering is what keeps the two layers from both populating the model.
- `""` is the sentinel for "nothing inherited", which is how a cold start differs from a reload that legitimately carried an empty store.
- `persistHistory()` returns early until `historyRestored` is set: a notification landing in the same event-loop turn as a reload would otherwise overwrite rows it has not restored yet.
- Both layers receive the **same** snapshot string, so a reload handoff and the disk copy never disagree about what the store held.
- Restore inserts oldest-first at the head, so a notification that arrived before the store settled keeps its place as the newest entry. After inserting, it trims and re-serializes, which normalizes malformed or legacy rows for next time and fills the handoff on a cold start.
- `parseHistory()` is defensive: non-JSON or non-array content yields no rows, per-field types are checked, and rows with nothing renderable (empty summary, body, and app name) are dropped. Missing `timestamp` defaults to `Date.now()`.
- `FileView` settings, verified against the installed Quickshell/Qt sources: `atomicWrites` (QSaveFile writes a sibling temp file and renames over the target, so a crash mid-write leaves the previous snapshot intact), `blockWrites` (each mutation is committed before returning, so an immediate shell exit cannot drop the last write — measured cost ~0.005 ms per write), `preload: false`, `blockLoading: true`, `printErrors: false`. A missing parent directory chain is created on first write, and reading a non-existent file yields an empty string plus `onLoadFailed(FileNotFound)` rather than throwing — hence `printErrors` stays off for a clean first run.
- `onLoadFailed` warns only for codes other than `FileNotFound`; `onSaveFailed` always warns.
- The path is under the shell's XDG state directory, never the repository.
- `NotificationServer { keepOnReload: true }` preserves the D-Bus server identity; the persistence layers above are what preserve the *rows*.

### DND, mute, and IPC

- `soundMuted` and `doNotDisturb` are plain `bool` properties, default `false`, and are authoritative for both the surfaces and the control center.
- IPC: `quickshell ipc call notifications toggleSound` (an `IpcHandler` in `shell.qml`) flips `notifications.soundMuted` only. There is no IPC target for DND, dismissal, or clearing.
- `NotificationControlCard.qml` toggles `soundMuted` and `doNotDisturb` directly through the injected `notificationsState`, and its `Clear all` calls `clearAll()`.
- `Bar.qml`'s notification icon reads the same instance: `doNotDisturb` selects the glyph, `recentModel.count > 0` sets the active tint, and `doNotDisturb || soundMuted` sets the warning tint.

### Store consumed by the control center

- `Bar.qml` uses `notificationsState.recentModel.count > 0` for the icon's active state — i.e. retained history, not what is currently on screen.
- `NotificationControlCard.qml` derives `notificationCount` from `recentModel.count`, reads rows through `recentModel.get(index)`, renders at most `maxVisibleNotifications: 3` newest-first rows (`sourceIndex = count - 1 - index`), and reports the remainder as `+N more recent notifications`.
- Row dismissal calls `notificationsState.dismissAt(sourceIndex)`: bounds-checked against the store, it resolves the row's `notifId`, dismisses and removes any live toast carrying that id, then removes the store row and persists.
- `clearAll()` dismisses every live notification, clears both models, and persists.

## Verified at runtime

Observed on the live session (one `quickshell` process, pid `400230`):

- `hyprctl layers` reports **two** toast surfaces per notification, one per monitor, each at real height: `4089 48 380 84` (`DP-1`, 2560-wide) and `1529 368 380 84` (`DP-2`, 1920-wide). Both anchored top-right on their own output. At idle both collapse to height `1`, which is the empty-stack case.
- The offsets match the tokens exactly, confirming per-screen anchoring rather than one surface painted twice: `margins.top = Theme.barHeight + Theme.spacingMd - 1` = `37 + 12 - 1` = `48`, and `DP-2` starts at `y = 320`, so its surface lands at `320 + 48 = 368` — precisely what the layer list shows. `margins.right = Theme.spacingMd - 1` = `11`, matching each surface's own right edge (`4089 + 380 = 4469`, `1920 + 2560 - 11 = 4469`; `1529 + 380 = 1909`, `1920 - 11 = 1909`).
- A test notification retired on schedule from both surfaces while `notification-history.json` under `~/.local/state/quickshell/by-shell/<hash>/` gained the row and kept it — direct evidence that expiry does not reduce the store.

## Open items

- No IPC or keyboard route for DND; only the control center toggles it.
- Toast height is content-driven, so a very long body can grow the stack beyond the available screen height; there is no clamp or scroll.
