# Right-island power sibling and actionable interaction standard

Status: implemented and reload-verified; commit and merge into `main` authorized by Ricardo.

## Goal
Treat Power as a local sibling section of the right-island controller instead of a separate global overlay root. Establish the right island as the first concrete application of the general actionable-element interaction standard.

## Local sibling model
```text
right-island
├── wifi
├── bluetooth
├── audio
├── notifications
└── power
```

All five immediate affordances are siblings in one local interaction authority. Their content may contain descendants, but descendants do not become competing roots.

## Required behavior
- Same sibling clicked again: toggle the local section closed.
- Different sibling clicked: switch directly to that sibling without teardown or the global 50 ms timer.
- Child/detail clicked: descend within the current sibling context.
- Parent clicked while a child is open: provisionally return to the parent.
- Click outside the island surface: close the local controller.
- Escape: close the local controller.
- Unrelated global root: close the island and open the requested root through the shared timer.
- No hover-open behavior.
- N-monitor routing remains based on the owning Bar instance and screen identity only; no monitor-specific geometry.

## Implementation contract
- `activeOverlay` remains `right-control-center` while any of the five siblings is active.
- `activeSection` carries `power` alongside the existing service sections.
- `activePath` becomes `right-control-center/power` for the power section.
- PowerMenu's trigger remains visually destructive and pill-shaped, but its menu content is owned by `RightControlCenter`'s in-surface tree.
- Remove the PowerMenu fullscreen `PanelWindow`, its separate backdrop, and the temporary `externalToggle` bridge.
- Route IPC and existing launcher power entry points to `openRightControlCenter(..., "power")`.
- Preserve keyboard navigation and destructive actions (reboot, poweroff, logout) inside the local power section.

## General actionable standard
For every future actionable element (button, list, row, toggle, or detail control), define before implementation:
1. Its immediate sibling/root context.
2. Its parent/child path and local owner.
3. Same-node toggle behavior.
4. Sibling transition behavior.
5. Descendant transition behavior.
6. Parent-return behavior when a child is open.
7. Pointer press/hover/disabled/loading/error behavior.
8. Outside-click, Escape, focus, and screen ownership behavior.
9. Whether a transition is local or requires global root replacement.

Child components emit intent upward; the owning local controller and `shell.qml` perform routing. No actionable component opens a competing fullscreen surface for a sibling interaction.

## Verification
- Qt6 qmllint on all touched QML files.
- Soft and hard Quickshell reload with `Configuration Loaded` and no `ERROR`.
- Live checks on both outputs: power toggle, power→Wi-Fi switch, Wi-Fi→power switch, service sibling switches, outside click, Escape, keyboard power actions, IPC power toggle, unrelated-root replacement, pass-through while closed.

## Verification evidence
- Qt6 qmllint exit 0 on `Bar.qml`, `RightControlCenter.qml`, `PowerMenu.qml`, and `shell.qml`; only documented/pre-existing diagnostics remain.
- `git diff --check` exit 0.
- Soft reload: terminal `Reloading configuration...` → `Configuration Loaded`, no post-reload ERROR.
- Hard reload: terminal `Reloading configuration...` → `Configuration Loaded`, no post-reload ERROR.
- Pointer behavior remains pending live confirmation: power toggle, power→Wi-Fi switch, Wi-Fi→power switch, outside click, Escape, keyboard actions, and unrelated-root replacement.

## Delivery
- Work-unit commit: `6c25a3a` (`feat(quickshell): make power a right-island sibling`) on `fix/right-island-input-ownership`.
- Merge that commit into `main` after verification.
- No push unless separately requested.
