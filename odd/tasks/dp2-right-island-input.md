# DP-2 right-island input discrepancy

Status: closed — the DP-2 repeated same-chip interaction problem is resolved by the current single-surface right-island implementation and the `activewindow` close-filter removal. Quickshell source is clean relative to `HEAD`; this task record captures the diagnosis and closure evidence. The earlier screen-origin subtraction hypothesis was live-tested and disproved: Qt pointer coordinates were already output-local.

## Goal
Diagnose and fix the live discrepancy where repeated same-chip toggle behavior works on DP-1 but not DP-2, while preserving the logical interaction-tree contract and N-monitor behavior.

## Observed behavior
- DP-1: same right-island chip can be clicked repeatedly without moving the pointer; panel opens/closes.
- DP-2: reported not to perform the same repeated toggle.
- DP-2 bar appears visually larger; live compositor reports both outputs at scale 1.

## Constraints
- Preserve one global overlay and logical path routing.
- Do not add monitor-specific behavior or infer monitor ordering.
- Keep `wezterm/.wezterm.lua` and `hyprland/.config/hypr/hyprland.conf` untouched.
- Confirm the failure source before editing.

## Investigation checklist
- [x] Capture live bar and overlay geometry per output — superseded: the live log pattern (`do-open ... -> opened ... -> bar-rcc-closed` with no routing request) identifies the defect as input redelivery, not geometry.
- [x] Confirm `Bar` screen identity and right-island hit regions — routing was correct; the close came from the panel's own backdrop, not from a second routing request.
- [x] Check layer/input stacking while panel is open — the full-screen `PanelWindow` maps above the bar, so its full-surface input region steals clicks aimed at the compact right island.
- [x] Hard reload and retest state if necessary — n/a.
- [x] Separate physical-size perception from logical geometry — n/a for this defect; the race reproduced on DP-1 and DP-2, both scale 1.

## Root cause (confirmed)
The full-screen `PanelWindow` occupies the entire output and its default input region covers the compact right island. While the panel is open, a click on a right-island chip never reaches the underlying `Bar`; it lands on the panel's full-surface backdrop `MouseArea`, which closes the panel instead of routing the chip's toggle/section request. Live logs show `do-open DP-2 right-control-center wifi` -> `opened right-control-center DP-2 right-control-center/wifi` -> `bar-rcc-closed DP-2` with no intervening routing request; the same pattern occurred on DP-1.

The earlier arming-timer diagnosis treated a symptom (the opening click redelivering to the backdrop) rather than the structural defect: the panel's input region never excluded the right island, so the chips stayed unreachable for the entire time the panel was open, which is why the second-click toggle never worked.

### Second confirmed cause: unfiltered global `activewindow` event

Live evidence showed the right-control-center opening on DP-2 and then closing immediately, with no routing request in between. The close came from `shell.qml`'s raw Hyprland event handler: the global `Connections { target: Hyprland }` block treated `activewindow` as a focus-loss event and called `overlayManager.closeAll()`. When the panel's `PanelWindow` maps with `WlrKeyboardFocus.OnDemand`, the compositor emits an `activewindow` (or `focusedmon`) event for that focus transition, so the same event that accompanies the open tears the panel back down. This is **not** a monitor-specific geometry problem: it is an unconditional close rule that is too aggressive for an OnDemand layer surface on any screen. The monitor-dependent appearance came from which screen happened to surface the focus event first, not from DP-1/DP-2 geometry.

## Fix
The final implementation eliminates the competing-surface race instead of trying to patch it with panel pass-through holes or one-click guards. The right-control-center is rendered inside the owning `Bar` surface, making the per-screen Bar the single input-authority surface for chips, power, backdrop clicks, and Escape.

- `bar/Bar.qml` spans the full output height but keeps the same top/left/right anchoring and exclusive zone. Its composed mask includes the left/center/right bar islands plus the right-control-center backdrop region only while the panel is open.
- `bar/RightControlCenter.qml` is now in-surface content (`Item`, no own `PanelWindow`), below the right-island chips in hit order. Closed state collapses the backdrop to `0x0`, so the mask contributes no input region while the control center is closed.
- Same-chip toggle and sibling switching are normal in-tree interactions: the compact service chips and power pill keep receiving direct clicks, and `openSection(section)` updates local content without tearing down and remapping a second layer surface.
- Escape focus is handled by the Bar surface while the control center is open; the in-surface key handler closes the panel without relying on a separate popup window.
- `shell.qml` removed `activewindow` from the raw Hyprland event list that unconditionally called `overlayManager.closeAll()`. Workspace/workspacev2/moveworkspace/movewindow/fullscreen handling is preserved; the closing comment records that an OnDemand layer surface's own focus transition fires `activewindow`, so keeping it in the list closed the panel it had just opened.
- All temporary `[interaction-debug]` and `[island-debug]` instrumentation was removed.

Historical notes: the failed intermediate `Region`/`Xor` pass-through and bounded opening-click guard explained parts of the race, but the durable fix is the single-surface right-island architecture committed in the Quickshell source.

## Coordinate-origin hypothesis (disproved)

A hypothesis was tested that the full-output `PanelWindow` reports backdrop pointer positions in the compositor's global canvas frame rather than the output-local frame. On this host DP-2 sits at global `(0, 320)` and DP-1 at `(1920, 0)`, so a global-frame `mouse.y` on DP-2 would carry a +320 offset and fall outside the output-local island rectangle.

The test change subtracted the owning `ShellScreen` origin (`screenOriginX`/`screenOriginY` derived from `screenTarget.x`/`screenTarget.y`, null-safe `0` fallback) from `mouse.x`/`mouse.y` before the in-island hit test. Live verification showed no behavior improvement, disproving the hypothesis: Qt's `MouseArea` `mouse.x`/`mouse.y` are already output-local (origin at the surface's top-left, positive y downward), matching the frame of the owning Bar's right-island rectangle. Subtracting `ShellScreen.x/y` was therefore wrong — the global-canvas placement offset is simply not part of the delivered position.

The subtraction was reverted before the final single-surface refactor. The general monitor-position independence requirement is preserved: the final control center lives in the owning Bar's screen-pinned surface, uses that local input tree directly, and contains no monitor-name, fixed-offset, resolution, or ordering special cases.

## Verification
- Reverted output-local rectangle re-linted: `/usr/lib/qt6/bin/qmllint -I quickshell/.config/quickshell quickshell/.config/quickshell/bar/RightControlCenter.qml` exits 0 with only the documented `PanelWindow is not creatable` [uncreatable-type] limitation. No new `missing-property` or `Quick.layout-positioning` defects.
- Qt6 lint (`/usr/lib/qt6/bin/qmllint -I quickshell/.config/quickshell <file>`) passes on `shell.qml`, `bar/Bar.qml`, `bar/RightControlCenter.qml` with only the documented `PanelWindow ... not creatable` [uncreatable-type] and `margins` [unqualified]/[unresolved-type] limitations. No `missing-property` or `Quick.layout-positioning` defects. (`shell.qml` also reports a pre-existing `unused-imports` Info for `Quickshell.Wayland`, unrelated to this change.)
- Soft and hard reload both end in `Configuration Loaded` with no `ERROR` after the last `Reloading configuration...`.
- Standalone pure-QML headless probe remains impractical for the layer-shell behavior; final behavior was confirmed through live compositor use rather than a headless probe.
- Closure verification delegated on 2026-10-03: `git diff --exit-code HEAD -- quickshell` exits 0, confirming there is no pending Quickshell source diff for this task; relevant source changes are already in commits such as `6c25a3a`, `71b4142`, and `bfa42b8`.
- Closure lint command: `/usr/lib/qt6/bin/qmllint -I quickshell/.config/quickshell quickshell/.config/quickshell/bar/Bar.qml quickshell/.config/quickshell/bar/RightControlCenter.qml quickshell/.config/quickshell/bar/PowerMenu.qml quickshell/.config/quickshell/shell.qml` exits 0 with only documented Quickshell `PanelWindow`/`margins` limitations and an unrelated unused-import Info.
- User live verification: Ricardo reported the problematic behavior is resolved. No additional reload or compositor action was run during this closure pass.

## Acceptance criteria
- [x] Same-chip repeated click works on both DP-1 and DP-2 — resolved per user live verification.
- [x] No opening-click guard remains necessary in the final design — single-surface input ownership removes the redelivery race.
- [x] Sibling switching remains local and screen-owned — `openSection(section)` changes local in-surface content without remapping another surface.
- [x] Power pill remains local to the right-island control-center path and opens the power section in the same surface.
- [x] No monitor-specific constants or routing exceptions — only the owning `Bar` instance's own `rightTab`/chip geometry is used.
- [x] Qt6 lint passes; soft/hard reload report `Configuration Loaded` with no ERROR.
- [x] Documentation records the actual cause and evidence — this document.
- [x] Coordinate-origin subtraction is reverted — live test disproved the hypothesis; `mouse.x`/`mouse.y` are already output-local and `ShellScreen.x/y` must not be subtracted.
