# Right-island focused-monitor focus POC

Status: implemented; user-confirmed behavior

## Goal

Evaluate a non-modal RightControlCenter focus policy: retain the panel while focus remains on its owning monitor, release keyboard capture through `OnDemand`, and close the panel when focus moves to another monitor.

## Scope

- Switch the owning Bar from `Exclusive` to `OnDemand` while RightControlCenter is open.
- Observe Hyprland `focusedmon` transitions in `shell.qml`.
- Close only when the focused monitor differs from the active overlay's owning screen.
- Do not use `activewindow` as a generic close trigger; opening an OnDemand surface can emit a focus event of its own.
- Preserve existing same-output backdrop click, Escape, workspace-change, and global media-key behavior.

## Acceptance checks

- [x] Qt 6 lint has no new diagnostics from the POC.
- [x] Opening the Right-island does not leave the application keyboard globally blocked (user-confirmed).
- [x] A focus change to another monitor closes the Right-island (user-confirmed).
- [x] Same-monitor external focus does not close it unless the existing backdrop receives the click (user-confirmed).
- [x] Escape closes it when the Bar key handler owns focus (user-confirmed).
- [x] Media/volume key binds remain compositor-global by Hyprland configuration inspection.
- [x] Runtime reload completes with `Configuration Loaded` and no `ERROR`.

## Verification record

- `git diff --check`: passed.
- Qt 6.11 `qmllint`: no diagnostics at the POC lines; only pre-existing Quickshell/type-resolution warnings remain.
- Soft reload: passed; log contained `Reloading configuration...` followed by `Configuration Loaded`, with no `ERROR`.
- Interactive verification was confirmed by the user: keyboard, same-monitor focus, cross-monitor dismissal, Escape, and media-key behavior are correct.

## Delivery

The POC is accepted for normal use based on user-confirmed keyboard, pointer, cross-monitor, Escape, and media-key behavior.

## Known limitation to verify

`OnDemand` focus behavior is compositor-dependent. The opening focus transition must be guarded so the panel does not close immediately after opening. The in-panel password TextInput may take focus away from the shared Escape handler; this POC records that behavior but does not redesign input focus routing.
