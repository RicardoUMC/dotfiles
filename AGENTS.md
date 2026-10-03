# AGENTS.md — dotfiles (Arch Linux + Hyprland + Quickshell)

## Stack
- **WM**: Hyprland 0.56.2 (`hyprctl version`), GPU AMD RX 7600
- **Shell UI runtime**: Quickshell 0.3.1 (`quickshell-git 0.3.1.r10.g2d3b3e9-1`) on Qt 6.11 (`qt6-declarative 6.11.2`)
- **Monitors** (verified via `hyprctl monitors`): `DP-1` 2560x1440 at 1920x0 (focused), `DP-2` 1920x1080 at 0x320 — both scale 1. The wider display sits to the **right** of the narrower one and they differ in height; nothing may infer ordering, adjacency, or a shared origin. Shell must stay N-monitor generic; see `specs/multi-monitor.md`.
- **Shell UI**: Quickshell (QML/Qt6) — entry point `~/.config/quickshell/shell.qml`
- **SDDM theme**: `tokyo-city` at `/usr/share/sddm/themes/tokyo-city/`
- **Dotfiles manager**: `stow` — each package mirrors `$HOME` structure

## Stow packages
| Directory | Stow target |
|-----------|-------------|
| `quickshell/` | `~/.config/quickshell/` |
| `hyprland/` | `~/.config/hypr/` — includes `scripts/brightness`, the DDC/CI panel-brightness helper (mode `755`, invoked by the `XF86MonBrightness*` binds) |
| `sddm/` | `/usr/share/sddm/themes/` |
| `wezterm/` | `~/.config/wezterm/` |

Install: `cd ~/dotfiles && stow quickshell hyprland wezterm`

## Quickshell architecture

```
shell.qml               ← coordinator: owns all overlay state, IPC handlers, the enabled-screen
                          list (`screenSelector`), the per-screen Bar `Variants`, `barForScreen()`
                          routing, the one shared 50 ms overlay timer, and `workspaceMonitorTick`
bar/Bar.qml             ← one PanelWindow instance PER SCREEN at `WlrLayer.Top` (declared explicitly, not the
                          Quickshell default); owns independent section surfaces, union input mask, in-place
                          center notch/dashboard, and screen-pinned panel surfaces
bar/Workspaces.qml      ← per-MONITOR workspace chips: filters the global Hyprland workspace model by
                          monitor-name identity, active state from its own monitor (never focusedMonitor)
bar/BarSection.qml      ← reusable per-section masked silhouette surface and hit region wrapper for left/center/right bar islands
bar/NotchIslandMask.qml ← mask geometry for each bar island body and gap-facing notch corners
bar/NotchCornerMask.qml ← Canvas-drawn corner mask primitive used by island and wrap masks
bar/CenterDashboard.qml ← tabbed body for the expanded center notch: Media pane + live Metrics pane
bar/MetricsPane.qml     ← center dashboard Metrics pane: CPU/RAM/GPU visual cards + single-row DSK/NET/VOL footer
bar/MetricCard.qml      ← reusable metric card with progress bar, Canvas sparkline, percent/N/A state
bar/SystemStats.qml     ← shared metrics dataState with scalar stats, 32-sample histories, and gpuAvailable flag
bar/CenterPanel.qml     ← invisible Escape/outside-click catcher for the in-place center notch (screen-pinned)
bar/StateLayer.qml      ← passive hover/press fill overlay (Caelestia-inspired state-layer grammar); sized to its owner, takes an explicit radius, never owns input
bar/RightIslandIconButton.qml ← reusable right-island service chip: fill/shape/accent state grammar (disabled/on/active/warning, no border) + StateLayer hover, deep-links into the control center
bar/RightControlCenter.qml ← right-island control center: PanelWindow Top surface hosting the specialty cards
bar/WifiControlCard.qml ← Wi-Fi specialty card: hero block, nearby-network list, connect/password/forget detail sheet
bar/BluetoothControlCard.qml ← Bluetooth specialty card: adapter hero, connected/available device groups, pair sheet
bar/AudioControlCard.qml ← Audio specialty card: output hero, volume slab using Theme.panelVolumeTrackHeight, routing group
bar/AudioControlPanel.qml ← nested audio device detail panel for input/output selection
bar/NotificationControlCard.qml ← notification specialty card: DND/sound state plus recent-notification list
bar/MetricsControlCard.qml ← system metrics card fed by the shell-level SystemStats state
services/WifiService.qml ← pragma Singleton — Wi-Fi state and actions (scan/connect/forget) via shell commands
services/BluetoothService.qml ← pragma Singleton — Bluetooth adapter, discovery, device, and pairing state
services/AudioService.qml ← pragma Singleton — PipeWire/WirePlumber outputs, inputs, volume, and mute state
bar/PowerMenu.qml       ← fullscreen PanelWindow Top (WlrLayer.Top), pinned to its bar's screen; its trigger is a pill-shaped destructive button (resting red tint + StateLayer), visually distinct from the service chips
bar/MprisPopup.qml      ← fullscreen PanelWindow Top, pinned to its bar's screen; reachable only via launcher outside-click
bar/MetricsDropdown.qml ← dormant: instantiated and screen-pinned per bar, but has NO open trigger. `MetricsButton.qml` was deleted. See `specs/overlay-manager.md`
launcher/LauncherCentered.qml ← fullscreen PanelWindow Top, pinned to the focused monitor
notifications/Notifications.qml ← ENGINE (non-surface `Item`): one NotificationServer, one sound player,
                                   one retained history + one live toast model, both persistence layers.
                                   Presentation is a per-screen `Variants` of PanelWindow toast surfaces (Overlay, top-right)
theme/Colors.qml        ← pragma Singleton — readonly color + font tokens
theme/Theme.qml         ← pragma Singleton — mutable structural tokens from config.json
theme/Motion.qml        ← pragma Singleton — shared motion vocabulary: named intents (Effects / EffectsColor / Spatial) as drop-in inline animation types; see "Motion system" below
```

There is no `bar/MetricsButton.qml` — the right island exposes Wi-Fi, Bluetooth, Audio, and Notifications chips plus the power button. Telemetry lives in the center dashboard Metrics pane and `MetricsControlCard.qml`.

**Every QML module needs its type declared in the local `qmldir` file** — missing entries cause `Type X unavailable` errors on load. Singleton registration works the same way: `theme/qmldir` carries `singleton Motion 1.0 Motion.qml` alongside `Colors` and `Theme`.

## Motion system

`theme/Motion.qml` is a `pragma Singleton` exposing named-intent animation types so call sites carry no duration or easing literals:

```qml
Behavior on opacity { Motion.Effects { } }       // short state feedback (numeric)
Behavior on color   { Motion.EffectsColor { } }  // same intent, ColorAnimation variant
Behavior on height  { Motion.Spatial { } }       // geometry that moves or grows
```

- Timing derives from `Theme.animFast`/`animSlow` × `Theme.animScale` (`anim.scale`, default `1.0`, clamped 0.25–3.0); `anim.enabled: false` makes shared Motion animations instantaneous, while `anim.overrides` can disable named parts such as `wallpaper.carousel` or `wallpaper.apply` selectively. Unmigrated call sites still use `Theme.anim*` directly — the primitive is opt-in per call site.
- Curves are the Qt 6.11 **6-value** Bézier form `[x1, y1, x2, y2, 1, 1]`. The CSS-style 4-value form is rejected at runtime and **silently animates linear** (qmllint does not catch it). The singleton probes curve support once against a real `NumberAnimation` and falls back to `Easing.OutCubic` when unsupported.
- **Never add `pragma ComponentBehavior: Bound` to a singleton that declares inline `component` animation types consumed from other files.** Qt 6.11 silently drops bound inline-component instances created by external `Behavior` call sites — motion snaps while qmllint stays clean. Inline components also cannot see the enclosing `id`; they bind through the singleton type name (`Motion.effectsDuration`, etc.).
- Adapted from Caelestia's motion *principle* (intent-named animation), not copied; see `specs/theme-system.md`.

The right island's Caelestia-inspired visual pass (state-layer chips, semantic divider, power pill, Motion pilot) is **implemented and lint/offscreen-verified but not yet confirmed on the live compositor**; the feature document is `odd/tasks/caelestia-right-island.md`.

The future configurable-bar design is documented in `specs/configurable-bar.md` and is **not implemented**. It defines global defaults with name-based per-monitor overrides for position (`top`/`bottom`/`left`/`right`), visibility (`always`/`edge-reveal`/`disabled`), style (`islands`/`continuous`), and dashboard attachment (`embedded`/`detached`). Edge reveal must use only external monitor edges; shared monitor seams remain pointer-traversal space. Do not treat these planned keys as current `Theme.qml` or `config.json` behavior.

## Overlay system rules (enforced in shell.qml)
- Overlay exclusivity is a **single global slot**: one `activeOverlay` plus one `activeScreenName`. Opening any overlay closes whatever was active, on any screen. There are **no context groups** — the `bar-primary` / `bar-secondary` grouping older notes described was never implemented. See `specs/overlay-manager.md`.
- The overlay renders on the screen whose Bar instance requested it; bar-owned overlays pin their `PanelWindow` to that screen explicitly
- Use a **50ms Timer** before opening a new overlay to avoid Wayland serial conflicts — exactly one shared timer for the session, never one per bar
- Overlays open/close **only on explicit user interaction** — never on hover
- `Escape` closes the active overlay (handled by the focused surface, not the manager); closing a parent tears down the whole active surface, including any expanded child content inside it
- Coordination lives in `shell.qml` — components signal up, never talk to each other directly
- Layer-shell `Overlay` is **reserved for transient system feedback** — notification toasts and the OSD; every interactive panel (bar, launcher, power menu, MPRIS popup, center catcher, metrics dropdown, right control center) lives in `Top`. Layer-shell has no raise-to-front request and stacks within a layer by mapping order, so a panel sharing `Overlay` with the toasts could silently cover a notification that arrived first. Panel-vs-panel order needs no such protection because exclusivity is a single global slot. See `specs/overlay-manager.md`
- Notification toasts and the OSD are **not** managed overlays: passive Overlay-layer surfaces that never take keyboard focus

## SDDM quirks
- SDDM 0.21: context globals (`userName`, `userPassword`, etc.) are **injected by the QML engine** — never redeclare them as `property var`
- Test theme without logging out: `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/tokyo-city`

## Typography system
All components use font-family tokens from `Colors.qml` — never hardcode font families:
| Token | Font | Use |
|-------|------|-----|
| `Colors.uiFont` | SF Pro Text | Labels, buttons, body text, metric values |
| `Colors.displayFont` | SF Pro Display | Large titles, headers |
| `Colors.monoFont` | VictorMono Nerd Font | Nerd Font icons, separators |

## Mutable structural tokens
`Theme.qml` reads structural token overrides from `quickshell/.config/quickshell/config.json` with hot-reload. Key bar tokens currently in use:
- `Theme.barScreens` — which monitors get a Bar: `"all"` (default) or an array of `ShellScreen.name` values; matched by name only, and an empty resolution falls back to all screens. See `specs/multi-monitor.md`
- `Theme.barChipHeight` — chip height shared by workspaces, control-center icons, and power button
- `Theme.barCurveRadius` — shared wrapped-silhouette corner radius
- `Theme.barWrapDepth` — decorative downward wrap depth below the interactive bar content
- `Theme.centerCollapsedWidth` — collapsed center notch width
- `Theme.centerExpandedWidth` — expanded in-place center dashboard width
- `Theme.centerExpandedHeight` — expanded in-place center dashboard height
- `Theme.dashboardRailWidth` — vertical tab rail width inside the expanded center dashboard
- `Theme.dashboardBodyRadius` — expanded dashboard body corner radius
- `Theme.dashboardBodyOpacity` — expanded dashboard body background opacity
- `Theme.dashboardBodyBorderWidth` — expanded dashboard body border width
- `Theme.dashboardBodyPadding` — inner margin around `CenterDashboard.qml`
- `Theme.dashboardTabHeight` — vertical rail tab height
- `Theme.dashboardTabSpacing` — spacing between vertical rail tabs
- `Theme.dashboardCardHeight` — Metrics pane card height
- `Theme.dashboardCardGap` — Metrics pane vertical card gap
- `Theme.dashboardProgressHeight` — Metrics card progress bar height
- `Theme.dashboardProgressRadius` — Metrics card progress bar radius
- `Theme.dashboardSparklineWidth` — Metrics card sparkline width
- `Theme.dashboardSparklineHeight` — Metrics card sparkline height
- `Theme.dashboardFooterHeight` — Metrics pane footer row height
- `Theme.rightPanelOpacity` — right control-center outer surface opacity (`rightPanel.opacity`, default `0.94`); inner card surfaces stay subtly translucent
- `Theme.accentSeamWidth` — specialty-card hero accent seam width (`panel.accentSeamWidth`); deliberately independent from `Theme.dashboardProgressHeight`
- `Theme.panelVolumeTrackHeight` — Audio card volume track and knob thickness (`panel.volumeTrackHeight`)
- `Theme.islandChipRadius` — right-island service-chip corner radius (`island.chipRadius`, default `8`)
- `Theme.islandActiveFillOpacity` — accent-tinted fill opacity for active/warning chips (`island.activeFillOpacity`, default `0.18`)
- `Theme.islandStateLayerHoverOpacity` — hover overlay opacity on right-island chips and the power pill (`island.stateLayerHoverOpacity`, default `0.10`)
- `Theme.islandStateLayerPressedOpacity` — pressed overlay opacity on the same surfaces (`island.stateLayerPressedOpacity`, default `0.16`)
- `Theme.islandSemanticGap` — extra whitespace on each side of the service/power separator (`island.semanticGap`, default `4`)
- `Theme.islandSeparatorWidth` — hairline dividing service chips from the power action (`island.separatorWidth`, default `1`); `0` removes **both** the line and its semantic gap
- `Theme.islandPowerTintOpacity` — resting red tint of the destructive power pill (`island.powerTintOpacity`, default `0.10`)
- `Theme.animScale` — global motion multiplier applied by the `Motion` singleton (`anim.scale`, default `1.0`, clamped 0.25–3.0); does not rewrite `animFast/animNormal/animSlow` for unmigrated call sites
- `Theme.debugBarSilhouette` — high-contrast red debug silhouette; do not disable unless Ricardo explicitly asks

## Multi-monitor rule
The shell is **N-monitor generic** — never assume a monitor count, index, or stable ordering. Full spec: `specs/multi-monitor.md`.
- One Quickshell process and one engine instance session-wide; `SystemStats`, `Notifications`, and Hyprland compositor-refresh orchestration live in `shell.qml`
- One surface instance per screen (bar, toast surface) via `Quickshell.screens` + `Variants`; per-screen UI duplicates views, never probes or IPC handlers
- Bar-owned overlays (power menu, MPRIS popup, center catcher, metrics dropdown, right control center) pin to their bar's screen through `screenTarget` — a nested `PanelWindow` does **not** inherit an output
- The launcher and the OSD follow the **focused monitor**, resolved by name against `ShellScreen` and written only while the surface is unmapped
- `WifiService`, `BluetoothService`, and `AudioService` are `pragma Singleton`, so they are already safe from per-screen duplication
- Overlay exclusivity is global across screens: at most one overlay open per session, rendered on the screen that requested it

## Configurability-first UI rule
- For UI/layout work, always evaluate which visual structure values should be user-configurable through `Theme.qml` + `config.json` before hardcoding them.
- Prefer exposing high-leverage structural knobs: padding, gaps, component heights, widths, radii/curves, opacity, border width, chart dimensions, and dashboard/bar proportions.
- Keep color and font families in `Colors.qml`; keep mutable layout/shape values in `Theme.qml` with safe defaults and optional `config.json` overrides.
- Avoid token sprawl: do not expose one-off decorative constants unless they materially help Ricardo tune the UI.
- Document any new tokens in `DESIGN.md`, `AGENTS.md`, and relevant `specs/*.md` via `sync-docs` after implementation.

## Palette — Tokyo City Terminal Dark (Base16)
Key values used in components:
- `base00` `#171D23` — background
- `base01` `#1D252C` — surface/cards
- `base0D` `#539AFC` — accent/blue
- `base0C` `#70E1E8` — cyan (reserved for special workspace highlight)
- `base08` `#D95468` — red/danger

## Hardware paths (data engine in SystemStats.qml, hoisted to one shell.qml instance)
- GPU busy: `/sys/class/drm/card1/device/gpu_busy_percent` — `card1` is the RX 7600 (`0x7480`); `card0` is the Raphael iGPU (`0x164e`)
- Disk: `nvme0n1`
- Network status: default route detection via `ip route`
- **Panel brightness: `ddcutil` over DDC/CI only.** `/sys/class/backlight` is **empty** on this host, so `brightnessctl` never touches a panel. `hyprland/.config/hypr/scripts/brightness up|down` resolves the focused connector to a ddcutil display index (cached per connector under `$XDG_STATE_HOME/hyprland-brightness`, self-healing on a failed DDC/CI access), reads VCP `0x10` for current+max, clamps the ±5 step, writes the absolute value, then reports the applied percentage to the OSD via `quickshell ipc call osd showBrightness`.
- Brightness binds are `bindl` (no `e`): one press costs ~650 ms of DDC/CI (`getvcp` ~297 ms + `setvcp` ~354 ms), so hold-to-repeat would queue dozens of execs. Intentional, not an oversight.

## IPC commands
```bash
quickshell ipc call launcher toggle
quickshell ipc call powermenu toggle
quickshell ipc call notifications toggleSound
quickshell ipc call osd showVolume
quickshell ipc call osd showBrightness <pct:int>
quickshell ipc call shellreload soft
quickshell ipc call shellreload hard
```

`launcher` and `powermenu` triggers carry **no screen identity**; they resolve through `barForScreen("")`'s documented first-instance path. The launcher then pins itself to the focused monitor on open, but an IPC-triggered power menu opens on the first bar instance — observed live with `DP-2` focused. See `specs/multi-monitor.md`.

## Verification — QML linting

The shell runs on **Qt 6.11** (`qt6-declarative 6.11.2`). Use the Qt 6 linter:

```bash
/usr/lib/qt6/bin/qmllint -I quickshell/.config/quickshell <file.qml>
```

- `/usr/bin/qmllint` belongs to **qt5-declarative 5.15** (`qmllint --version` prints `qmllint 1.0`) and provides **zero coverage** on this Qt 6.11 codebase. `/usr/lib/qt6/bin/qmllint` (`qmllint 6.11.2`) is the only linter to trust. The Qt5 binary has **two** failure modes, and its silence means nothing in either one — never read it as a pass:
  - On Qt 6 files that use optional chaining (`?.`) it aborts with exit `255` and no diagnostics. A clean-looking `255` is a crash, not a verdict.
  - On files without `?.` it exits `0` and prints **nothing at all**, including on files where the Qt 6 linter reports genuine defects.

  Verified on this host against `sddm/themes/tokyo-city/components/UserCard.qml` (the pre-fix copy of that file, still present at the installed theme path):

  ```bash
  /usr/bin/qmllint quickshell/.config/quickshell/bar/Workspaces.qml                    # exit 255, no output (file uses ?.)
  /usr/bin/qmllint /usr/share/sddm/themes/tokyo-city/components/UserCard.qml           # exit 0,   NO output
  /usr/lib/qt6/bin/qmllint /usr/share/sddm/themes/tokyo-city/components/UserCard.qml   # 3 warnings: two Quick.layout-positioning + one [unqualified]
  ```

  An exit `0` from `/usr/bin/qmllint` is therefore **not** a lint pass — on that same file the Qt 6 linter found two of the real defects listed below. Only Qt 6 output counts.
- Expect and ignore these known linter limitations against Quickshell types:
  - `uncreatable-type` on `PanelWindow` — qmllint does not follow the `default import` in Quickshell's generated `qmldir`.
  - `unresolved-type` on the grouped `margins { }` property.
  - `missing-property` on state handed through `property var` (e.g. `systemStatsState.cpu`) — the value is untyped, so the linter cannot see the source `QtObject` properties. Typing these properly is the fix; do not silence them ad hoc.
  - `[unqualified]` warnings are style-level.
- Treat these as **real defects** and fix them:
  - `missing-property` where `parent` is a layout (`parent.radius` on a `ColumnLayout` child silently resolves to undefined).
  - `Quick.layout-positioning` — `anchors`/`height` on an item managed by a layout is undefined behavior; use `Layout.*`.
- To settle Quickshell API semantics, read the installed source rather than guessing: `/usr/src/debug/quickshell-git/quickshell/src` (shipped by `quickshell-git` debug package).

## Applying and verifying QML changes

The live shell **no longer auto-reloads on file save** from the next session
start onwards: `hyprland.conf` launches it as `env QS_DISABLE_FILE_WATCHER=1 quickshell`,
so editing `bar/*.qml` no longer triggers mid-save reloads on partially written
multi-file changes.

- **Apply changes** (deliberate, after a coherent edit is on disk):
  ```bash
  quickshell ipc call shellreload soft   # Quickshell.reload(false) — keeps process state
  quickshell ipc call shellreload hard   # Quickshell.reload(true) — full rebuild
  ```
- **Verify the reload actually took**:
  ```bash
  timeout 20 quickshell log | sed 's/\x1b\[[0-9;]*m//g' | tail
  ```
  Acceptance signal: `Configuration Loaded` with **no `ERROR`** after the last
  `Reloading configuration...`. Anything else means the new config is broken and
  the shell is running the previous graph.
- **Escape hatch** (restore watching without editing any config): launch or
  restart the shell without `QS_DISABLE_FILE_WATCHER` in its environment.
  `Quickshell::watchFiles()` is gated on that variable, so its absence puts the
  watcher back on.

## Commit style
Conventional commits: `feat(scope): message`, `fix(scope): message`, `refactor(scope): message`
Merge directly to `main` — no PRs (personal repo). Never commit without explicit user request.

## Design system
See `DESIGN.md` for the full design reference — philosophy, inspirations, tokens, overlay rules, and planned architecture. Read it before touching any UI component.

## Reference-first feature workflow
- Ambxst/Ax-Shell is a reference implementation for inspiration, not a source to copy wholesale.
- Before implementing a feature inspired by Ambxst, inspect how Ambxst solves the same problem, then compare at least one alternative approach with pros and cons.
- Final decisions must adapt the idea to this shell's architecture, tokens, overlay rules, and Ricardo's personal design goals.
- Keep the reference clone outside this repository. Current local reference path: `/home/unseen/src/reference/Ambxst`.
- Caelestia (`caelestia-dots/shell`) is a second reference at `/home/unseen/src/reference/Caelestia`, used for the right-island visual pass. Same rule applies: principles (state-layer fill grammar, intent-named motion) are adapted, never copied; the Tokyo City palette, overlay architecture, and no-hover-open rule are preserved.
- Do not vendor, stow, or copy Ambxst files into `dotfiles` unless Ricardo explicitly asks for a deliberate port.

## Available skills (OpenCode)
| Command | Skill | Purpose |
|---------|-------|---------|
| `/sync-docs` | `sync-docs` | Sync SPECS.md, DESIGN.md, AGENTS.md, specs/* to reflect current implementation state |

## Do not touch
- `~/.config/opencode/` — managed by `gentle-ai` (AGENTS.md, opencode.json, skills/, commands/)
- Never add `--no-verify`, amend commits, or force push
