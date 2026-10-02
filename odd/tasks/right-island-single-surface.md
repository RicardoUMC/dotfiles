# Right-island single input surface

Status: implemented and reload-verified; power sibling follow-up approved in `odd/tasks/right-island-power-sibling.md`. Supersedes the two-surface input-steal design recorded in `odd/tasks/dp2-right-island-input.md` (its confirmed facts stay valid: redelivery behavior, disproved origin hypothesis, `activewindow` removal).

## Goal
Give each monitor ONE input-authority surface: the per-screen Bar. The right control center (RCC) stops being a competing fullscreen `PanelWindow` and becomes content inside the Bar's surface, with a dynamic composed `Region` mask. This removes, by construction, the mechanism behind the flaky DP-2 second-click: the panel-owned backdrop, the coordinate classifier, and the timed one-shot opening-click guard.

## Why (evidence)
- `dp2-right-island-input.md`: repeated in-island clicks only work through a `ignoreOpeningBarClick` guard bounded by a 50 ms expiry Timer. Redelivered opening clicks and deliberate clicks are only distinguishable by timing → race. Live symptom: second click does not reliably close the panel on DP-2.
- Reference comparison (Engram obs 700): Ambxst (`UnifiedShellPanel`) and Caelestia (`ContentWindow`) both keep exactly one fullscreen interactive surface per screen with a dynamic composed mask; neither lets a bar and a popout own competing fullscreen surfaces. Both avoid coordinate-reimplemented hit tests by keeping everything in one input tree.
- Quickshell source `/usr/src/debug/quickshell-git/quickshell/src/core/region.cpp`: `Region { item: }` reconnects to the item's `x/y/width/height` changes only — it is **visibility-blind**. So the dynamic mask must be driven by the backdrop's GEOMETRY (0×0 when closed), and the backdrop `MouseArea` must be disabled exactly when its region is empty, or the surface swallows desktop clicks with nothing to consume them.

## Approved design (adapted from Caelestia, not copied)
1. **Bar surface goes full-output height** — `implicitHeight` = owning `screen.height` (fallback to the old content-height formula while `screen` is null). Anchors stay `top/left/right` ONLY: no bottom anchor, so the exclusive zone remains unambiguously top-edge. `exclusiveZone: Math.ceil(reservedBarContentHeight)` is unchanged, so tiled windows never move.
2. **RCC becomes an Item inside Bar** — no own `PanelWindow`, no `screenTarget`. `panelBody` keeps its current output-local anchoring (top-right, `Theme.barHeight + Theme.spacingMd - 1` top margin), because the Bar window's origin equals the old popup surface's origin (both top-left of the output).
3. **Composed dynamic mask** — `mask: Region { regions: [leftSection.hit, centerSection.hit, rightSection.hit, Region { item: backdrop }] }`. Backdrop geometry: full-parent when `isOpen`, 0×0 otherwise; `visible`/`enabled` track the same flag.
4. **One input tree, native routing** — chips and the power pill keep their own `MouseArea`s at higher z than the RCC root (`z: -1`), so same-chip toggle, sibling switch, and descendant interaction are plain Qt click handling. No `barRightIsland*` rect, no `classifyRightIslandInteraction`, no `rightIslandInteractionRequested`, no `ignoreOpeningBarClick`, no `openingClickGuardExpiry`.
5. **Outside click = backdrop click** — low-z full-surface `MouseArea` active only while open; `onClicked → close()` → `closed()` → coordinator `overlayManager.close()` (idempotent re-entry already guarded by `if (!isOpen) return` in `close()`).
6. **Escape/focus** — `keyHandler` moves inside the RCC Item. Bar sets `WlrLayershell.keyboardFocus: rightControlCenter.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None`; `onVisibleChanged`-style focus request becomes open-time `forceActiveFocus()`. `activewindow` stays out of the raw-event close list (unrelated to this change; prior reasoning preserved).
7. **Power sibling follow-up** — Power is being promoted from the temporary external-toggle bridge into a local `right-control-center/power` sibling section. See `odd/tasks/right-island-power-sibling.md`; the bridge is intentionally temporary and will be removed in that unit.

## Preserved contracts
- One global overlay root + `activePath` logical tree (`interaction-tree-routing.md`) — `shell.qml` semantics unchanged: same node toggles closed, sibling switches locally via `bar.openRightControlCenterSection()`, different root/screen closes globally then opens through the shared timer.
- N-monitor genericity: no monitor names, offsets, positions, or resolutions in logic; per-screen state lives in the per-screen Bar instance (Caelestia's local ScreenState principle, adapted).
- No hover-open; layer policy unchanged (panels Top, Overlay reserved for toasts/OSD).
- Provisional rule (Engram obs 699): clicking a parent while a child is open returns to the parent — deferred until a real nested path exists (AudioControlPanel / Wi-Fi detail); nothing here pre-empts it.

## Non-goals (explicitly deferred)
- Consolidating MprisPopup / MetricsDropdown / CenterPanel catcher into the Bar surface (PowerMenu is no longer deferred; it is the next local sibling slice).
- The launcher `onOutsideClicked` coordinate duplication (`powerBtnGlobalX` / `mprisChipGlobalX`) — becomes simpler later, not in this slice.
- Docs sync (`sync-docs`, `specs/overlay-manager.md`, `DESIGN.md`) after implementation + live acceptance.
- Push remains deferred; Ricardo explicitly authorized the power sibling commit and merge into `main`.

## Tasks
- [x] T1 Bar full-output surface + reactive composed mask + keyboardFocus flip (`bar/Bar.qml`)
- [x] T2 RCC converted to in-surface Item with geometry-driven backdrop; delete guard/classifier/island-rect (`bar/RightControlCenter.qml`)
- [x] T3 PowerMenu `externalToggle` hook + Bar binding (`bar/PowerMenu.qml`, `bar/Bar.qml`)
- [x] T4 Qt6 lint all touched files; soft+hard reload; `Configuration Loaded` with no ERROR
- [ ] T5 Live behavior matrix on both outputs (Ricardo): same-chip toggle ×N; sibling switch; descendant open (Wi-Fi detail / Audio panel); outside click closes; Escape closes; workspace switch closes; power pill while open replaces root; desktop click pass-through while closed; tiled windows unmoved
- [ ] T6 Record results here + Engram; note residual deferred items

## Implementation notes (writer handoff, verified by parent)
- One deviation from the literal brief, accepted: `restartPanelReveal()` added to `open()` and to `openSection()`'s closed→open branch, because the removed popup `onVisibleChanged` used to be the only reveal trigger. Without it `panelBody.height` would stay 0.
- Dead imports (`Quickshell`, `Quickshell.Wayland`) removed from `RightControlCenter.qml` with the PanelWindow; no `rightControlCenterOpen` consumers existed.
- Semantic change intentionally accepted by design: bar elements above the backdrop (workspaces, center tab, chips) keep native input while the RCC is open. Workspace clicks still close via the raw-event `closeAll`; center/other-root clicks close via coordinator replacement. Non-interactive section area falls through to the backdrop and closes.
- `gentle-ai-worker` task id: `muqccogf-1-rt6p`. Lint at handoff: exit 0 on all three files, only documented known limitations.

## Acceptance criteria
- Second (and Nth) deliberate click on the same chip closes the panel deterministically on any output — no timing guard exists anywhere in the path.
- The opening gesture can never reach a rival surface: press and release of every island interaction occur within one `PanelWindow`.
- No code references monitor identity, offsets, or hand-derived island coordinates.
- Closed state input behavior is bit-identical to today: mask = three section hits, everything else pass-through.
