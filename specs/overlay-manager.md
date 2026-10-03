# Overlay Manager

**Status:** Implemented
**Files:** `overlayManager` `QtObject`, `overlayOpenTimer`, `screenSelector`, `barVariants` and `barForScreen()` in `quickshell/.config/quickshell/shell.qml`, routing in `bar/Bar.qml`, consumers `launcher/LauncherCentered.qml`, `bar/PowerMenu.qml`, `bar/MprisPopup.qml`, `bar/MetricsDropdown.qml`, `bar/CenterPanel.qml`, `bar/RightControlCenter.qml`

## Description

Centralized overlay coordinator declared in `shell.qml`. It owns a single active-overlay identity plus the screen that requested it, serializes every open through one shared 50 ms timer, and guarantees that at most one overlay is visible in the session. Components never open or close each other directly: they emit a request signal upward, the manager decides, and the manager calls back into the owning `Bar` instance to show or hide a surface.

Exclusivity is **one global slot, no groups**. There is exactly one `activeOverlay` string, so exclusion is unconditional: opening anything closes whatever was active, on any screen.

## Behavior

### Managed overlay names

`overlayManager` addresses overlays by string. Verified names in `shell.qml`:

| Name | Surface | How it is opened |
|------|---------|------------------|
| `launcher` | `LauncherCentered` (shell-level instance, not bar-owned) | `launcher` IPC handler; `_doOpen` calls `launcher.toggleOpen()` |
| `powermenu` | `PowerMenu` popup inside a `Bar` instance | `powermenu` IPC handler, right-island power chip click, launcher outside-click routing |
| `mpris` | `MprisPopup` inside a `Bar` instance | launcher outside-click routing only |
| `metrics` | `MetricsDropdown` inside a `Bar` instance | no live emit site — registered infrastructure, see below |
| `center-panel` | `CenterPanel` catcher + in-place center notch | `centerPanelToggleRequested` from the center tab |
| `right-control-center` | `RightControlCenter` inside a `Bar` instance | right-island icon clicks (`openRightControlCenter(screenName, section)`) |

- Notification toasts and the OSD are **not** managed: `Notifications.qml` is an engine whose per-screen toast surfaces and `OsdWindow.qml` are passive `Overlay`-layer surfaces that never enter the exclusivity set, never take keyboard focus, and are not closed by `closeAll()`.

### Reachability of each name (verified against emit sites)

- `launcher`, `powermenu`, `center-panel`, `right-control-center` (section form) are reachable: they have live emit sites (`IpcHandler`s, the `Bar` center-tab mouse area, and the right-island icon buttons).
- `mpris` has exactly one live emit site: the launcher outside-click branch. The bar's own compact media chip does **not** open `MprisPopup` — `MprisIndicator.onClicked` selects the dashboard Media tab and requests `center-panel` instead. So the standalone popup is reachable only by dismissing a click through the launcher onto the media chip.
- `metrics` is registered in the manager (`_doOpen` → `bar.openMetrics()`, `_closeActive` → `bar.closeMetrics()`, `Bar` exposes `openMetrics()`/`closeMetrics()` and `metricsOpened`/`metricsClosed`) but **no UI element emits a metrics toggle anywhere in the tree**. `MetricsButton.qml` was deleted, its `bar/qmldir` entry removed, and the never-emitted `Bar.metricsToggleRequested` / `Bar.mprisToggleRequested` signals plus their `shell.qml` handlers were removed with it. `MetricsDropdown.qml` remains on disk, instantiated in every `Bar`, screen-pinned, and fed `systemStatsState`.
  - **Decision, not oversight:** the dropdown stays as deliberately dormant infrastructure. Its wiring is intact and harmless, so restoring a metrics entry point is a one-signal change rather than a rebuild. The center dashboard `Metrics` pane and `MetricsControlCard` are the live surfaces for telemetry today.

### State ownership

- `property string activeOverlay` and `property string activeScreenName` are the root overlay state; there is no overlay stack and no list of open surfaces.
- Logical path state: `activeSection` mirrors the right-control-center child content (`""` = aggregate landing) and the derived readonly `activePath` is the one truth source for relationship comparison (`right-control-center`, `right-control-center/wifi`, ...). Both are built through the centralized `rightControlCenterPath(section)` helper so no visual component hardcodes path literals.
- Request state: `_pendingOpen`, `_pendingScreenName`, `_pendingRightControlCenterSection`.
- Visibility itself stays inside each surface (`popup.visible`, exposed as `isOpen` / `readonly property bool powerMenuVisible` etc.); the manager commands surfaces through `Bar.qml` functions (`openPowerMenu()`, `closeMpris()`, `closeCenterPanel()`, `closeRightControlCenter()`, `openRightControlCenterSection(section)`) and through `launcher.visible` for the launcher.
- The manager lives in `ShellRoot`, so a `Bar` reload or a per-screen instance never recreates the coordination state.

### Global exclusivity

- `open(screenName, name)` closes whatever is active before queueing the new overlay: `_pendingRightControlCenterSection = ""` → `_closeActive()` → set `_pendingScreenName` / `_pendingOpen` → `overlayOpenTimer.restart()`.
- Opening the overlay that is already active on the same screen is a **toggle**: `if (activeOverlay === name && activeScreenName === screenName) { _closeActive(); return }`.
- `close(screenName, name)` is a guarded no-op unless both the name and the owning screen match the active pair, so a stale `closed()` signal from a surface on another screen cannot clear a newer overlay.
- `closeAll()` is only `_closeActive()` — because exclusivity is global, there is never more than one surface to tear down.
- Cross-screen consequence: opening from `DP-2` closes the overlay owned by `DP-1` first, then opens the requester's after the timer.

### No context groups

The manager implements no group table, no group membership, and no per-group comparison. The `bar-primary` / `bar-secondary` grouping that older drafts of this spec described **was never implemented**; the active set has always been a single `activeOverlay` string, and the code now documents itself that way.

- Same-group "coexistence" is a consequence of composition, not of group logic: `center-panel` does not open a separate visible panel but expands the bar's own center notch in place, and `right-control-center` hosts its section cards (Wi-Fi, Bluetooth, Audio, Notifications) as content inside that one surface, so switching sections is not an overlay transition.
- `_closeActive()` clears `activeOverlay`/`activeScreenName` **before** hiding the surface, specifically so the surface's own `closed()` signal re-entering `overlayManager.close()` cannot cascade. That guard is what makes single-slot state safe with signal-driven teardown.
- Group-era language has been purged from every live document, including the two that once described the model as if it existed: `skills/interaction-designer/SKILL.md` now states the single global slot and warns against designing for `bar-primary`/`bar-secondary`. What remains in those files is explicit negation, not a surviving model.
- Distinct from groups, the **logical interaction tree** is now implemented (see below): it models relationships *within* one root surface as paths, not as a multi-window stack, so it does not resurrect group semantics.

### Logical interaction tree

Implemented (lint-verified; live pointer confirmation pending): the coordinator models the right-control-center's child content as a logical path tree, not as concurrent overlays. `activeOverlay` stays the single global root identity; `activeSection` mirrors the child content (`""` = aggregate landing), and the derived `activePath` is the one truth source for relationship comparison.

```text
root
└── right-control-center
    ├── wifi
    ├── bluetooth
    ├── audio
    │   └── device-panel (reserved descendant shape; current panel remains content)
    └── notifications
```

Transition rules, implemented in `openRightControlCenter(screenName, section)`:

- **Same path on the same screen toggles closed** — `activePath === rightControlCenterPath(section)` routes through the re-entrancy-guarded `_closeActive()`.
- **A sibling path switches local content** — same screen, same root, different child calls `bar.openRightControlCenterSection(section)` in place and updates `activeSection` truthfully: no teardown, no timer restart, screen ownership preserved.
- **A descendant path preserves its parent and opens child content inside the owning surface.** The concrete descendant `right-control-center/audio/device-panel` is reserved in comments only; the current audio device panel remains content inside `RightControlCenter`, not a routed node.
- **A different root or screen closes globally first, then opens through the shared 50 ms timer** — the existing close-then-open path.
- **Rapid pending requests replace rather than queue** — one `_pendingRightControlCenterSection` slot, `overlayOpenTimer.restart()` on every queued open.

`_closeActive()` clears `activeSection` alongside `activeOverlay`/`activeScreenName` before hiding the surface, and `_doOpen()` sets `activeSection` from the pending section before consuming it, so `activePath` stays truthful through every open and close. The empty-section aggregate path (`right-control-center`) stays coherent even though its entry point is dormant.

Concurrent parent/child overlays remain **out of scope**: no multi-window stack, no change to the single-slot exclusivity rule, no `Top`/`Overlay` layer change. Feature document: `odd/tasks/interaction-tree-routing.md`.

### Layer policy

Layer-shell gives each surface a layer, and this shell uses exactly two of them:

| Layer | Surfaces |
|-------|----------|
| `WlrLayer.Top` | `Bar.qml`, `LauncherCentered.qml`, `PowerMenu.qml`, `MprisPopup.qml`, `MetricsDropdown.qml`, `CenterPanel.qml`, `RightControlCenter.qml` |
| `WlrLayer.Overlay` | the per-screen toast surfaces in `Notifications.qml`, `OsdWindow.qml` |

**The rule:** `Overlay` is reserved for transient system feedback — notification toasts and the OSD. Every interactive panel lives in `Top`.

The reason is a protocol constraint, not a style choice. `wlr-layer-shell` offers no raise-to-front request, and within a single layer the stacking order is the order in which surfaces were mapped. While the control center and the toast surfaces shared `Overlay`, a panel mapped after a notification arrived silently covered it — the user-reported bug. Separating the layers makes "the toast and the OSD sit above every panel" a guarantee of the protocol instead of a race the shell happened to win.

This is safe for the panels' mutual order because exclusivity is a single global slot: at most one interactive panel is visible at a time, so no two `Top` panels compete for the same screen region.

Two implementation details worth keeping in mind:

- `Bar.qml` declares `WlrLayer.Top` **explicitly** even though Quickshell's own default is `Top` (`/usr/src/debug/quickshell-git/quickshell/src/wayland/wlr_layershell/surface.hpp:22`). The bar was already Top by default; the declaration exists so a future change to that default cannot silently move the bar out of the layer the panels assume.
- A new panel must declare `WlrLayer.Top` on its `PanelWindow`. Relying on the default is how the bar's layer used to be implicit, and the default is Quickshell's decision, not this shell's.

**Residual limitation, not addressed by this policy:** a third-party client in the `Overlay` layer — another notification daemon, a screen-recorder overlay, a locker surface — can still map above these toasts. The policy guarantees that the shell's own feedback outranks the shell's own panels; it does not claim supremacy over other clients' Overlay surfaces.

### The 50 ms anti-serial-conflict timer

- `Timer { id: overlayOpenTimer; interval: 50; repeat: false }` is declared at `ShellRoot` level, outside the `QtObject`, because the open logic needs a timer that survives per-screen instance churn.
- `onTriggered: overlayManager._doOpen(overlayManager._pendingScreenName, overlayManager._pendingOpen)`.
- **One shared timer for the whole session.** Global exclusivity means there is never more than one pending open, so multiple `Bar` instances must not multiply it (`specs/multi-monitor.md` requirement). `_doOpen` is where the pending screen identity is resolved.
- Every `open()` path ends in `overlayOpenTimer.restart()`, so a rapid second request replaces the pending one instead of queueing: exactly one open ever lands, and the close of the previous overlay happens immediately while the new open happens 50 ms later.
- Purpose: the gap avoids Wayland serial conflicts caused by tearing down one layer surface and grabbing keyboard/pointer for another in the same request.

### Close triggers

- **Explicit close / toggle:** `overlayManager.open()` on the active name+screen, or `overlayManager.close(screenName, name)`.
- **Click outside:** each managed surface installs its own full-surface `MouseArea` backdrop (`PowerMenu`, `MprisPopup`, `MetricsDropdown`, `CenterPanel`, `RightControlCenter`, `LauncherCentered`) that hides the popup and emits its `closed()` signal; content areas consume their own clicks so they never reach the backdrop.
- **Escape:** handled by the focused surface, not by the manager — `PowerMenu` (Escape closes), `CenterPanel`, `MetricsDropdown`, `RightControlCenter` (Escape → `close()`), and `LauncherCentered` (Escape in `navigate` mode closes; Escape in `search` mode only switches mode). `MprisPopup.qml` is the exception in the managed set: it declares no `keyboardFocus` and has no key handler, so it dismisses by outside click only.
- **Workspace / window change:** the `Connections { target: Hyprland }` block in `shell.qml` calls `overlayManager.closeAll()` when a raw event name is one of `workspace`, `workspacev2`, `moveworkspace`, `movewindow`, `activewindow`, `fullscreen`. This is global focus loss and is independent of which screen emitted it.
- **Opening an incompatible overlay:** `_closeActive()` inside `open()`.
- No timeout-based close exists in the manager; only the OSD self-dismisses (`2500 ms`), and it is not managed.
- Dismissal always flows back through `Bar.qml` signals (`powerMenuClosed`, `mprisClosed`, `metricsClosed`, `centerPanelClosed`, `rightControlCenterClosed`) connected per instance in the `Variants` delegate, keeping `activeOverlay` truthful.

### Surface signal contract

Signals emitted by managed surfaces are named `opened()` / `closed()`. `PowerMenu` previously declared `signal onOpened()`, and `Bar` bound `onOnClosed:` to a signal that did not exist — so closing the power menu silently never reached the manager and `activeOverlay` stayed set to `"powermenu"` after the menu was gone. Renaming to `opened()` / `closed()` fixed a real state leak: `Bar` now binds `onOpened` / `onClosed`, which resolve correctly.

Not every dismissal path emits `closed()`. Two do — `close()` and the backdrop click. Three do not: the activated-item paths (`PowerMenu.qml:138`, `:146`, `:159`, plus the mirrored `keyHandler.actions` array at `:103-107`) assign `popup.visible = false` directly and never emit, so an invoked Reiniciar/Apagar/Cerrar sesión leaves the manager's slot unset-by-teardown rather than clearing it through the signal path. This is currently harmless because each of those three actions ends the session anyway, and it is recorded as a known gap rather than a defect to fix in isolation — see `specs/power-menu.md`. Any future PowerMenu action that keeps the session alive must emit `closed()`, or the single-slot state will desync exactly the way the old handler mismatch did.

### Per-instance routing

Implemented and verified in `shell.qml`:

- `Variants { id: barVariants; model: screenSelector.enabledScreens }` creates one `Bar` per resolved screen, each with `screen: modelData` and `screenName: modelData.name`.
- `screenSelector.enabledScreens` resolves `Theme.barScreens` (`"all"` or a name array) by `ShellScreen.name` only, ignores unmatched names, falls back to all screens when the selection resolves empty, and re-evaluates on `Quickshell.screens` changes.
- Signal routing is inline per delegate instance, so every bar event carries its own `barInstance.screenName` into `overlayManager.open/close`.
- `barForScreen(name)` resolves the instance to command; an empty identity means "no screen intent" and returns the first available instance, and an unknown identity returns `null`.
- `_closeActive()` and `_doOpen()` both route through `barForScreen()`: a `null` result means the instance is gone, so the command is skipped and only manager state is cleared. `_doOpen()` returns before touching manager state when the instance is missing, so a failed open never leaves `activeOverlay` pointing at a surface that never appeared.
- Bar-hosted overlay surfaces pin to the requesting screen explicitly, not by nesting: `Bar.qml` passes `screenTarget: root.screen` into `PowerMenu`, `MetricsDropdown`, `MprisPopup`, `CenterPanel`, and `RightControlCenter`, and each forwards it to its own `PanelWindow` as `screen: root.screenTarget`. `null` keeps the compositor-picks-output default; a screen pins it. The in-code comment records why — an unpinned layer-shell surface sends a null `wl_output` to `get_layer_surface`, so the compositor chooses the output.

### Screen intent from IPC and keybinds

- `launcher` and `powermenu` IPC opens pass `""`, which resolves through the first-instance fallback rather than the focused screen. The launcher compensates for having no screen intent by resolving its own target output — see below — so `launcher` geometry reads come from the bar on the screen it actually renders on.
- `powermenu` opened by keybind therefore takes bar geometry from the first bar instance. Documented limitation, not a defect being hidden: `specs/multi-monitor.md` tracks focused-screen resolution for IPC-triggered bar overlays.
- The `launcher` slot is special-cased as a shell-level instance with an empty screen identity (`onDismissed: overlayManager.close("", "launcher")`), so launcher state is not screen-attributed in the manager even though the surface itself is screen-pinned.

### Launcher screen pinning and outside-click routing

`LauncherCentered` is opened by IPC/keybind rather than by a click on a given monitor, so it resolves its own output: it matches `Hyprland.focusedMonitor.name` against `ShellScreen.name` in `resolveTargetScreen()` and writes the result into a plain `targetScreen` property that `screen` reads. The write is imperative and happens **only while the surface is unmapped**, because `setScreen()` on a mapped surface unmaps and rebuilds it. Unresolvable focus keeps the previous pin.

- `shell.qml` reads `launcher.targetScreen` to pick the bar it defers to: `barForScreen(launcherScreen === null ? "" : launcherScreen.name)`. Bar geometry therefore comes from the instance on the screen the launcher actually covers, not an arbitrary one.
- Outside-click interpretation: `inBar = y < bar.reservedBarContentHeight`, then `x >= bar.powerBtnGlobalX` opens `"powermenu"`, otherwise a hit on the MPRIS chip band (`bar.mprisChipActive` and `x` within `mprisChipGlobalX ± mprisChipWidth / 2`) calls `bar.setMprisAnchor()` and opens `"mpris"`.
- `reservedBarContentHeight` is the max of the three section reserved heights and is the same value the bar hands the compositor as its exclusive zone — observed at `42` px on both monitors via `hyprctl monitors`. The earlier `y < Theme.barRailHeight` test compared against a 4 px decorative rail, so it could never be true over chips that are `Theme.barChipHeight` (30) tall, and every click on the bar just closed the launcher. Fixing the threshold restored reachability for both bar-chained opens.
- Screen pinning is what makes the x test meaningful at all. `outsideClicked` reports coordinates within the launcher's own surface, while `powerBtnGlobalX` / `mprisChipGlobalX` are relative to the bar surface. Those two frames only agree when the launcher and the bar are on the **same** monitor, which is exactly what `barForScreen(launcher.targetScreen.name)` now guarantees. Before the launcher pinned its screen, a mismatched pair compared numbers from two different monitors.
- **Horizontal precision, as implemented:** `mprisChipGlobalX` is defined in `Bar.qml` as `mprisChip.mapToItem(null, 0, 0).x + mprisChip.width / 2` — the media chip's real center in this bar's window coordinates — and falls back to `centerTab.x + centerTab.width / 2` only when the chip geometry is degenerate (non-finite center, `width <= 0`, or the window-relative center left of the chip's own `x`), which cannot reach the popup as a stale zero. `mapToItem()` is a function call the engine cannot observe, so the binding also reads `mprisChip.x` to register the dependency that re-evaluates it when the header fillers re-center the clock/chip pair. The collapsed header row is `[fill, ClockChip, MprisIndicator, fill]`: the equal fillers center the *pair*, so the chip's center sits right of the tab center by `(clockWidth + spacing) / 2`. The width term cancels, so that offset is **independent of the media chip's own width** and a longer title neither shrinks nor inverts it. Measured live in the running shell: `clockWidth ≈ 88.5`, `spacing = 8`, `(88.5 + 8) / 2 ≈ 48.3` px, observed `49` px (`RowLayout` rounds item geometry to integers). The band and the popup anchor now read this one property, so they cannot drift apart.
- **What this fixed.** While the band used the tab midpoint it sat `~48` px left of the visible chip, so band and chip barely overlapped: the chip's left part was inside the band and its right part was not, and the right edge of the clock chip was inside the band too. A click landing on the right part of the chip dismissed the launcher instead of opening the popup. The numbers above are a live geometry read from the running shell; no synthetic pointer click was performed, so click feel at the band boundary still needs eyes.
- **Intra-layer stacking is measured, not assumed.** The launcher and the bar are both `Top`. Capturing the bar band with the launcher closed versus open (`grim`, 900x42 px over the bar, state verified through `hyprctl layers` before each capture) shows 0.0 % of pixels changed and identical mean brightness, while the desktop behind it dims: **the bar renders above the launcher**. Consequence for input, which follows the same order — a click that lands on a chip reaches the chip's own handler even while the launcher is open, and stays exclusive only because that handler also goes through `overlayManager.open()`. The launcher's bar-band heuristic therefore applies to clicks in the transparent gaps between islands, not to the chips themselves. Not verified by a synthesized pointer click: this host has `wtype` (keyboard only) and no `ydotool`.
- **Consequence, decided:** because the fixed band is real, clicking the compact media chip through an open launcher opens the standalone `MprisPopup`, while clicking the same chip with no launcher open selects the dashboard `Media` pane and expands the center notch. Two entry points, two different surfaces — **Ricardo chose to keep both deliberately**, so the split is the design, not an oversight. Do not unify them in a future pass.

### Parent-child close cascade

There is no descendant registry; the cascade is achieved by two mechanisms that both live outside the manager:

- **Handoff through `open()`:** `LauncherCentered.onOutsideClicked` in `shell.qml` can route a launcher dismiss click straight into `overlayManager.open(bar.screenName, "powermenu")` or `"mpris"`. The launcher is hidden by its own surface first, then the manager closes the launcher slot and opens the child after the timer, so the parent never survives into the child's state.
- **Component-level state reset:** closing a parent hides its children and the children reset themselves on invisibility. `NotificationControlCard.qml` collapses `expanded` when it becomes invisible (and re-expands when `standalone`), and `RightControlCenter.open()` calls `resetSections()` before showing, so a fresh open never restores a previously expanded child card. `Bar.openRightControlCenterSection(section)` → `RightControlCenter.openSection(section)` → `activateSection()` also runs `resetSections()` first, so at most one child section is expanded per open.
- `CenterPanel` is the invisible input catcher for the expanded center notch: closing it collapses the notch body that `Bar.qml` mounts inside the same center tab, and the catcher punches a pass-through hole (`mask: Region { item: centerHole; intersection: Intersection.Xor }`) so controls inside the notch keep their own clicks while every other click closes the panel.
- With one global slot there is no subtree to walk — closing always tears down the entire active surface, including any expanded child content inside it. `DESIGN.md`'s "closing a parent overlay closes all its descendants" and "opening sibling overlays closes only the incompatible subtree" describe the same observable behavior in group language; the mechanism is a single-slot teardown plus per-component reset.

### Open sequencing rules

- Overlays open only on explicit user interaction (click, keybinding, IPC request). No `hovered` handler opens, closes, or replaces an overlay anywhere in the managed set; hover only changes selection or tint inside the already-open surface.
- For `"right-control-center"`, `_doOpen()` consumes `_pendingRightControlCenterSection` and clears it; an empty section string opens the plain landing state. Same-screen section requests route through `openRightControlCenter(screenName, section)` and follow the logical-tree transitions above — a same-path toggle or a sibling switch never tears the root down and never touches the 50 ms timer; only a different root or screen goes through the timer.

## Verified at runtime

- `hyprctl layers` shows a single `quickshell` process (pid `400230`) owning two bar surfaces, one per output: `1920 0 2560 272` (`DP-1`) and `0 320 1920 272` (`DP-2`). Two `Bar` instances exist, so per-instance routing and per-instance screen pinning are live, not merely declared.
- Shell log for the current graph ends in repeated `Configuration Loaded` with no `ERROR` after the last `Reloading configuration...`, which is this repo's acceptance signal that the loaded graph matches the files on disk.

## Open items

- `mpris` and `metrics` have no bar-side trigger; `mpris` is reachable only through the launcher chain, `metrics` through nothing.
- Overlay state is global while `activeScreenName` records only the owner; the launcher slot keeps an empty screen identity.
- IPC-triggered bar overlays resolve through the first-instance fallback instead of the focused screen.
