# Logical interaction tree routing

Status: implemented (lint-verified; live pointer confirmation pending)

## Goal
Strengthen actionable-element behavior across the shell by introducing logical interaction paths and relationship-aware transitions while preserving one global interactive overlay surface at a time.

## Approved architecture
- Use a logical tree/path model, not concurrent overlay windows.
- Keep one global overlay root (`activeOverlay` + `activeScreenName`) and the existing 50 ms Wayland serial-conflict timer.
- Model parent, sibling, descendant, and same-node relationships for content inside a root surface.
- Same node toggles closed; sibling switches locally; descendant opens inside its parent; unrelated root closes globally then opens after the timer.
- Do not reintroduce `bar-primary`/`bar-secondary` context groups or a multi-window overlay stack.

## Initial tree
```text
root
└── right-control-center
    ├── wifi
    ├── bluetooth
    ├── audio
    │   └── device-panel (reserved descendant shape; current panel remains content)
    ├── notifications
    └── power
```

## Acceptance criteria
- Repeated clicks on the same right-island service chip open/close the same section without moving the pointer.
- Clicking a different service chip while the right control center is active switches sibling content without tearing down the global root or losing screen ownership.
- Opening another root overlay still closes the right control center globally and respects the shared timer.
- Pending repeated requests replace one another; no queued duplicate opens.
- Escape, outside click, focus-loss close, and screen pinning remain unchanged.
- New routing vocabulary is centralized; child components continue to emit intent upward.
- Behavior and path tokens remain configurable only where structural tuning is broadly useful; no per-button routing literals are scattered into visual components.

## Planned files
- `quickshell/.config/quickshell/shell.qml`
- `quickshell/.config/quickshell/bar/Bar.qml`
- `quickshell/.config/quickshell/bar/RightControlCenter.qml`
- relevant interaction/overlay specs and `DESIGN.md` after implementation

## Non-goals
- No concurrent parent/child PanelWindows.
- No layer changes.
- No hover-open behavior.
- No service/backend changes.
- No new visual restyle in this unit.
- Preserve dirty user-owned `wezterm/.wezterm.lua` and `hyprland.conf`.

## Implemented

Path model and transitions centralized in `shell.qml`'s `overlayManager`; `Bar.qml` and `RightControlCenter.qml` needed no change. `activeOverlay` stays the single global root identity; a new `activeSection` field mirrors the right-control-center child content (`""` = aggregate landing), and a derived readonly `activePath` is the one truth source for relationship comparison. One helper `rightControlCenterPath(section)` builds full paths (`right-control-center`, `right-control-center/wifi`, ...) so no visual component hardcodes path literals.

Transition rules in `openRightControlCenter(screenName, section)`:
1. **Same screen + same path** → `_closeActive()` (toggle close, re-entrancy guarded).
2. **Same screen + same root + different child** → `bar.openRightControlCenterSection(section)` in place, no teardown, no timer; `activeSection` updated truthfully.
3. **Different root or different screen** → existing global close-then-open through the shared 50 ms timer.
4. Pending requests replace `_pendingRightControlCenterSection` (single pending slot, timer restart).

`_closeActive()` clears `activeSection` alongside `activeOverlay`/`activeScreenName` before hiding the surface, and `_doOpen()` sets `activeSection` from the pending section before consuming it, so the derived `activePath` stays truthful through every open/close. The empty-section aggregate path (`right-control-center`) stays coherent even though its entry point is dormant. Descendant shape `right-control-center/audio/device-panel` is reserved in comments only. Power follows the same local sibling contract at `right-control-center/power`; it is not a separate global root.

## General actionable-element standard

Every actionable element must be assigned to an immediate local sibling context before implementation. The owner defines the element's parent/child path, same-node toggle, sibling switch, descendant entry, provisional parent return, pointer press/hover/disabled/loading/error behavior, outside click, Escape, focus, and screen ownership. Child components emit intent upward; they do not open competing surfaces or decide global routing. Unrelated roots replace the local context through the global coordinator and shared timer.

## Normative trigger checklist

The tree transitions in "Approved architecture" are normative as written, not advisory. For any future actionable implementation, these must be defined before code, not discovered afterward: pointer hover and press, keyboard/focus, disabled state, loading/error state, repeated-click behavior, outside-click, `Escape`, and screen ownership. If any is ambiguous, the interaction-designer skill requires resolving it in the spec first.
