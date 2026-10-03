# DESIGN.md — Tokyo City Shell

Design system reference for the Hyprland + Quickshell rice.
This document is the source of truth for visual decisions, principles, and inspiration.
Any agent or future session should read this before touching UI components.

---

## Philosophy

> "Software, not rice."

The goal is a UI system, not a decoration layer. The difference:

- A rice decorates your environment and gets replaced in 3 weeks
- A UI system defines it with consistent design criteria — you use it for years

The shell should feel **fast, technical, clean, and modular**. "Hacker/dev workstation" is secondary inspiration — not literal. The benchmark is: does this feel like well-crafted software?

---

## Inspirations

### Dank Material Shell

**What to take:**

- Visual cohesion — everything feels intentional
- Material You principles: adaptive color, purposeful hierarchy
- Spacing consistency
- Typographic consistency
- Modern, polished feeling

**What to avoid:**

- Visual density overload
- Too many always-visible widgets (causes fatigue over time)

### Ambxst / Ax-Shell

**Primary inspiration** — the direction that fits this project most.

Ambxst is a reference to study, not a target to clone. For features inspired by it, first inspect the local reference implementation at `/home/unseen/src/reference/Ambxst`, understand the pattern, compare alternatives, then adapt the final design to this shell's own architecture and preferences.

**What to take:**

- Expandable dashboards
- Modular, composable panels
- Overlays and sidebars that slide in contextually
- Floating panels with depth
- Smooth animations
- Single-side accent border on cards (color left-border highlight for hierarchy)
- Settings GUI that exposes design tokens — change the look without touching code

**Why Ax-Shell specifically:** it feels like software, not a rice. It has design criteria, not just pretty colors.

### Caelestia (right-island visual pass)

**What was taken — principles only, no copied code:**

- **State-layer grammar:** transient interaction state (hover/press) is expressed as a flat fill overlay, never as a border. Local adaptation: `bar/StateLayer.qml`, a passive overlay the owning chip feeds its own hover/press booleans into.
- **State as fill + shape, not outline:** service state reads through fill tint and icon accent; a per-chip outline was removed because it reads "empty" regardless of state. Power is separated by *shape* (pill vs. tile) and a resting destructive tint, not by an added border.
- **Intent-named motion:** animations are addressed by named intent (effects vs. spatial), not by per-call-site duration/easing literals. Local adaptation: `theme/Motion.qml` driven by the existing `Theme.anim*` tokens plus one `anim.scale` knob; deliberately **not** Caelestia's Material-3 curve table or its C++ SDF/blob shader.

**What was explicitly not taken:**

- No code copying or vendoring; the reference lives outside the repo at `/home/unseen/src/reference/Caelestia`.
- No Material 3 palette or curve table — colors stay Tokyo City Base16 in `Colors.qml`.
- No hover-open behavior; the overlay rules (single global slot, `Top` vs. `Overlay` layering, 50 ms open timer) are unchanged.
- No overshooting spatial curves: Caelestia's own curves exceed 1.0 mid-flight, which would resize the content-driven control-center body past its own content. The adopted curves are monotonic within `[0, 1]`.

Status: implemented and verified by Qt 6 lint plus offscreen runtime probes; **live compositor visual confirmation and a debug-off screenshot are still pending**. Feature document: `odd/tasks/caelestia-right-island.md`.

### Future configurable bar direction

The current top-anchored island bar remains the implemented baseline. The future design is documented in [`specs/configurable-bar.md`](specs/configurable-bar.md) and is intentionally not represented as implemented configuration today.

The design separates four independent decisions:

- **Position:** `top`, `bottom`, `left`, or `right`, selected per monitor through global defaults and name-based monitor overrides.
- **Visibility:** `always`, `edge-reveal`, or `disabled`, with reveal and reservation state owned independently by each monitor's bar instance.
- **Style:** `islands` preserves the current curves, wraps, masks, gaps, and ornaments; `continuous` is a separate future visual grammar.
- **Dashboard attachment:** `embedded` keeps the dashboard visually attached to the bar; `detached` gives it an independent screen-pinned surface.

Edge reveal must use only external output edges. A seam shared by adjacent monitors stays free for pointer traversal and is never used as a generic reveal hit region.

---

## Design Tokens

Design tokens are split across two QML singletons:

- `theme/Colors.qml` — readonly palette and font-family tokens.
- `theme/Theme.qml` — mutable structural tokens loaded from `config.json` with hot-reload.

### Palette — Tokyo City Terminal Dark (Base16)

| Token    | Hex       | Semantic use                                             |
| -------- | --------- | -------------------------------------------------------- |
| `base00` | `#171D23` | Background                                               |
| `base01` | `#1D252C` | Surface / cards                                          |
| `base02` | `#28323A` | Elevated surface                                         |
| `base03` | `#526270` | Muted / disabled                                         |
| `base04` | `#B7C5D3` | Dim text                                                 |
| `base05` | `#D8E2EC` | Primary text                                             |
| `base06` | `#F6F6F8` | Bright text                                              |
| `base07` | `#FBFBFD` | White text                                               |
| `base08` | `#D95468` | Red / danger                                             |
| `base09` | `#FF9E64` | Orange                                                   |
| `base0A` | `#EBBF83` | Yellow                                                   |
| `base0B` | `#8BD49C` | Green                                                    |
| `base0C` | `#70E1E8` | Cyan — **reserved for special workspace highlight only** |
| `base0D` | `#539AFC` | Blue / accent                                            |
| `base0E` | `#B62D65` | Magenta                                                  |
| `base0F` | `#DD9D82` | Brown                                                    |

### Typography

| Token                | Font                 | Role                                                    |
| -------------------- | -------------------- | ------------------------------------------------------- |
| `Colors.uiFont`      | SF Pro Text          | Labels, buttons, body text, metric values, input fields |
| `Colors.displayFont` | SF Pro Display       | Large titles, headers, prominent text                   |
| `Colors.monoFont`    | VictorMono Nerd Font | Nerd Font icons, separators, monospace contexts         |

**Rule:** always use tokens — never hardcode font family names in components.

**Size scale.** Text and icon sizes are structural values in `Theme.qml` and are hot-reloadable through the `font.*` group in `config.json`:

| Token | Default | Config key | Role |
| ----- | ------- | ---------- | ---- |
| `Theme.fontSizeCaption` | `12` | `font.caption` | Eyebrow labels, secondary readouts, dense metadata |
| `Theme.fontSizeLabel` | `13` | `font.label` | Chip labels, buttons, compact control text |
| `Theme.fontSizeBody` | `15` | `font.body` | Default body and control text |
| `Theme.fontSizeBodyLg` | `17` | `font.bodyLg` | Prominent values, section titles |
| `Theme.fontSizeIcon` | `22` | `font.icon` | Nerd Font glyphs in bar and panel controls |

Current `config.json` keeps the scale at its defaults (`12 / 13 / 15 / 17 / 22`).

**Why SF Pro:** chosen over Geist and Outfit for the "premium software" feel. SF Pro Text for UI consistency, SF Pro Display for typographic hierarchy. Geist is installed but not used in the UI.

### Mutable structural tokens

`Theme.qml` exposes runtime-tunable structural values. Current bar-specific tokens include:

| Token | Default | Current config | Use |
| ----- | ------- | -------------- | --- |
| `Theme.barHeight` | `37` | `37` | Base top-bar offset used by overlays. |
| `Theme.barChipHeight` | `30` | `30` | Uniform chip height for workspace pills, metrics, power button, and right-island icon buttons. |
| `Theme.barCurveRadius` | `14` | `16` | Shared silhouette/notch curvature source. |
| `Theme.barWrapDepth` | `14` | `12` | Decorative downward wrap depth below the interactive bar content. |
| `Theme.centerCollapsedWidth` | `360` | `360` | Collapsed center notch width. |
| `Theme.centerExpandedWidth` | `520` | `520` | Expanded in-place center dashboard width. |
| `Theme.centerExpandedHeight` | `260` | `260` | Expanded in-place center dashboard height. |
| `Theme.dashboardRailWidth` | `44` | `44` | Vertical tab rail width inside the expanded center dashboard. |
| `Theme.dashboardBodyRadius` | `10` | `10` | Expanded dashboard body corner radius. |
| `Theme.dashboardBodyOpacity` | `0.35` | `0.35` | Expanded dashboard body background opacity. |
| `Theme.dashboardBodyBorderWidth` | `1` | `1` | Expanded dashboard body border width. |
| `Theme.dashboardBodyPadding` | `12` | `12` | Inner margin around `CenterDashboard.qml`. |
| `Theme.dashboardTabHeight` | `40` | `40` | Vertical dashboard rail tab height. |
| `Theme.dashboardTabSpacing` | `8` | `8` | Spacing between dashboard rail tabs. |
| `Theme.dashboardCardHeight` | `42` | `42` | Metrics pane card height. |
| `Theme.dashboardCardGap` | `4` | `4` | Metrics pane vertical card gap. |
| `Theme.dashboardProgressHeight` | `4` | `4` | Metrics card progress bar height. |
| `Theme.dashboardProgressRadius` | `2` | `2` | Metrics card progress bar radius. |
| `Theme.dashboardSparklineWidth` | `80` | `80` | Metrics card sparkline width. |
| `Theme.dashboardSparklineHeight` | `32` | `32` | Metrics card sparkline height. |
| `Theme.dashboardFooterHeight` | `18` | `18` | Metrics pane footer row height. |
| `Theme.rightPanelOpacity` | `0.94` | `0.94` | Outer background opacity of the right-island control-center surface (`rightPanel.opacity`). |
| `Theme.accentSeamWidth` | `4` | `4` | Hero accent seam width inside the three control-center specialty cards — Wi-Fi, Bluetooth, and Audio hero blocks (`panel.accentSeamWidth`). |
| `Theme.panelSecondarySeamWidth` | `2` | `2` | Accent seam of the nested audio device panel; deliberately thinner than the `accentSeamWidth` hero seam — do not merge them (`panel.secondarySeamWidth`). |
| `Theme.panelVolumeTrackHeight` | `8` | `8` | Audio card volume track and knob thickness (`panel.volumeTrackHeight`). |
| `Theme.islandChipRadius` | `8` | `8` | Right-island service-chip corner radius (`island.chipRadius`). |
| `Theme.islandActiveFillOpacity` | `0.18` | `0.18` | Accent-tinted fill opacity when a chip is active or warning (`island.activeFillOpacity`). |
| `Theme.islandStateLayerHoverOpacity` | `0.10` | `0.10` | Hover overlay opacity on the right-island chips and power pill (`island.stateLayerHoverOpacity`). |
| `Theme.islandStateLayerPressedOpacity` | `0.16` | `0.16` | Pressed overlay opacity on the same surfaces (`island.stateLayerPressedOpacity`). |
| `Theme.islandSemanticGap` | `4` | `4` | Extra whitespace on each side of the service/power separator (`island.semanticGap`). |
| `Theme.islandSeparatorWidth` | `1` | `1` | Hairline dividing service chips from the power action; `0` removes **both** the line and its semantic gap (`island.separatorWidth`). |
| `Theme.islandPowerTintOpacity` | `0.10` | `0.10` | Resting red tint of the destructive power pill (`island.powerTintOpacity`). |
| `Theme.animScale` | `1.0` | `1.0` | Global motion multiplier applied by the `Motion` singleton on top of `animFast/animNormal/animSlow`; clamped to 0.25–3.0; `1.0` preserves current timing exactly (`anim.scale`). |
| `Theme.animationsEnabled` | `true` | `true` | Global animation switch (`anim.enabled`). `false` makes all shared Motion animations instantaneous. |
| `Theme.animationOverrides` | `{}` | wallpaper overrides enabled | Named per-part exceptions (`anim.overrides`), e.g. `wallpaper.carousel: false` while all other motion remains enabled. |
| `Theme.wallpaperTransition` | `"fade"` | `"fade"` | `awww` wallpaper application transition (`wallpaper.transition`). Supported values include `none`, `simple`, `fade`, directional, `wipe`, `wave`, `grow`, `center`, `any`, `outer`, and `random`. |
| `Theme.wallpaperTransitionDuration` | `1.0` | `1.0` | Duration in seconds for supported `awww` transitions (`wallpaper.duration`). |
| `Theme.barStyle` | `"silhouette"` | `"silhouette"` | Enables the masked wrapped silhouette; `"plain"` disables it. |
| `Theme.barScreens` | `"all"` | `"all"` | Which screens get a bar: `"all"`, or an array of `ShellScreen.name` strings (`bar.screens`). Matching is by name only — never index or order; unmatched names are ignored; a resolved-empty set falls back to all screens so a session is never left without a bar. Architecture: `specs/multi-monitor.md`. |
| `Theme.barNotchGapWidth` | `30` | `30` | Horizontal gap at each section boundary of the silhouette (`bar.notchGapWidth`). |
| `Theme.barNotchDepthRatio` | `0.2` | `0.2` | Shared notch depth for all segments: depth = bar height × ratio (`bar.notchDepthRatio`). |

Debug scaffolding is also configurable through `debug.*` keys. `debug.barSilhouette` intentionally remains available for high-contrast silhouette tuning and should only be disabled when Ricardo explicitly requests it.

Dashboard body, rail, card, progress, sparkline, and footer geometry is configurable through the flat `Theme.dashboardXxx` properties above and the `dashboard.*` group in `config.json`. Defaults intentionally preserve the current center-dashboard visuals; large overrides may need proportional width/height tuning because the expanded notch remains bounded by `Theme.centerExpandedWidth` and `Theme.centerExpandedHeight`.

Control-center panel chrome is a separate group: `Theme.accentSeamWidth`, `Theme.panelSecondarySeamWidth`, and `Theme.panelVolumeTrackHeight` are read from the `panel.*` group, and `Theme.rightPanelOpacity` from `rightPanel.opacity`. Within that family the seams are deliberately distinct and must not be merged:

- `Theme.accentSeamWidth` (`4`) is the hero accent seam of the three specialty cards (Wi-Fi, Bluetooth, Audio hero blocks).
- `Theme.panelSecondarySeamWidth` (`2`) is the seam of the nested audio device panel — intentionally thinner than the hero seam.
- `Theme.panelVolumeTrackHeight` (`8`) is the Audio card volume track and knob thickness.

The hero seam is **deliberately decoupled** from `Theme.dashboardProgressHeight`; the two happen to share the value `4` but answer to different design decisions. `Theme.dashboardProgressHeight` remains the center-dashboard metric-bar token only — it is no longer reused as seam geometry anywhere, and panel seams never read from it.

---

## Visual System

### Density

**Balanced** — neither too compact nor too airy. Functional and clean. Enough padding to breathe, not so much it wastes space.

### Border Radius

Mixed system — radius is contextual:

| Context                                  | Radius    |
| ---------------------------------------- | --------- |
| Small UI elements (chips, buttons, tags) | `6–8px`   |
| Cards, popups, panels                    | `10–12px` |
| Large modals, overlays                   | `12–16px` |
| Pill shape (badges, indicators)          | `999px`   |

### Transparency & Blur

- **Default**: semi-transparent surfaces with moderate blur (glassmorphism light)
- **Configurable**: blur intensity exposed as a design token — user can increase to full glassmorphism
- Surface opacity roughly `0.93–0.97` for panels, `0.30–0.40` for background tints
- The right control-center outer surface is driven by `Theme.rightPanelOpacity` (default `0.94`, `rightPanel.opacity`) so the panel reads as one solid sheet; inner specialty cards and slabs stay subtly translucent and are not tied to that token.

### Accent Borders

Cards and panels may use a **single-side color highlight** (left border) to create visual hierarchy without adding noise. Color matches the contextual accent (urgency color for notifications, `base0D` blue for general panels).

### Right-Island State Grammar

The right island expresses state through **fill, shape, and a passive state layer** (adapted from Caelestia, see Inspirations):

- Service chips never carry their own outline; the wrapped bar silhouette already owns the edge. States: quiet `base01` fill when off, accent-tinted fill + accent icon when active, orange-tinted fill + orange icon when warning (warning wins over active), dimmed quiet fill when the adapter is disabled. Disabled takes visual precedence over active so a powered-off radio never reads live.
- Hover/press feedback is the `StateLayer` overlay at `islandStateLayerHoverOpacity` / `islandStateLayerPressedOpacity`, inheriting the owner's radius.
- Power is a **distinct object class**: a pill silhouette (`radius = height / 2`) with a resting red tint at `islandPowerTintOpacity`, not another service tile.
- A configurable semantic hairline separates the service group from the power action. It is purely decorative: no input, no routing change; `separatorWidth: 0` removes the line and its surrounding gap together.
- Fill state changes animate through `Motion.EffectsColor` because service state can flip while the chip is on screen; hover-driven icon color stays instant so pointer feedback never lags.

### Bar Style

**Wrapped floating silhouette** — not full-width. The bar is composed of independent left, center, and right islands with transparent gaps, anchored to the top of the screen. Inspired by macOS Sonoma / Ax-Shell and adapted from Ambxst's mask-composition idea.

The accepted silhouette design uses independent per-section surfaces coordinated by `Bar.qml`:

- `BarSection` wraps each left, center, and right island with its own masked fill surface and hit region.
- `Bar.qml` exposes one layer-shell input mask as the union of the three section hit regions, preserving transparent click-through gaps between islands.
- `NotchIslandMask` defines each separated island and its gap-facing top corner pieces.
- `NotchCornerMask` draws explicit curved mask pieces, including lateral downward wrap pieces.
- `exclusiveZone` reserves only the collapsed interactive/content height; the `PanelWindow` keeps a stable expanded-aware `implicitHeight` so opening the center dashboard does not resize the layer-shell surface or shift tiled windows.
- Side islands share `sideTabHeight`, while chips use `Theme.barChipHeight` for consistent internal rhythm.
- The center island expands in place into the dashboard. Its expanded body overlays app content and does not increase Hyprland reserved space.
- The expanded center notch hosts a small dashboard body with a vertical tab rail adapted from the Ax-Shell expandable-dashboard direction: Media preserves the existing MPRIS controls, while Metrics shows live CPU/RAM/GPU cards with progress bars, Canvas sparklines, and a single compact `DSK | NET | VOL` footer row.
- Metrics cards use contextual per-metric colors (`base09` orange for CPU, `base0D` blue for RAM, `base0E` magenta for GPU) and disabled muted treatment for unavailable GPU data. Disk/network/volume remain compact footer readouts for this first slice.
- Deferred metrics work: temperatures, multi-GPU presentation, zoom/refresh controls, charts libraries, and external/Python monitor processes are intentionally out of scope.
- Compact center media-chip clicks now select the dashboard Media tab and open the in-place center dashboard, keeping media interaction inside the expanded center notch.
- The standalone MPRIS popup remains available for launcher fallback and future explicit triggers, but it is no longer the visible compact-chip click behavior.

---

## Overlay System

Full spec: `specs/overlay-manager.md`. Overlays follow a **session-global exclusivity** model.

### Exclusivity rules

- Exclusivity is **one global slot**: `shell.qml` owns a single `activeOverlay` plus the single `activeScreenName` that requested it. There is no overlay stack and no list of open surfaces.
- **At most one overlay is open in the whole session, across all screens.** Opening any overlay closes whatever was active, including an overlay owned by a different monitor.
- The overlay renders on the screen whose `Bar` instance requested it; bar-owned surfaces pin their `PanelWindow` to that screen explicitly (`screenTarget` → inner `screen`).
- There are **no context groups**. The `bar-primary` / `bar-secondary` grouping older drafts of this document described was never implemented; nothing in `shell.qml` stores or compares group membership.
- Nested surfaces are **content, not overlays**. The audio device panel (`AudioControlPanel.qml`) lives inside the `RightControlCenter` surface, and the control-center section cards live inside that same surface, so opening or switching them is not an overlay transition and cannot close a parent. That composition — not a group table — is what lets a nested panel stay open without a second slot.

### Close triggers

The active overlay must close when:

- Click outside its interactive area
- Another overlay opens (the slot is singular — see above)
- `Escape` is pressed
- Global focus is lost (workspace change, window switch)
- Explicit close action

### Activation rules

- Overlays open/close **only on explicit user interaction**
- Hover must **never** open, close, or replace any overlay
- This prevents: accidental focus changes, interruptions during repeated clicks, involuntary activations between close elements

### Hierarchy

- With one slot there is no subtree to walk: closing the active overlay tears down the **entire surface**, including any expanded child content mounted inside it
- Child content resets itself on invisibility (`NotificationControlCard` collapses its expansion; `RightControlCenter.open()` calls `resetSections()`), so a fresh open never restores a previously expanded child
- Keyboard navigation acts on the single active surface

### Logical interaction paths

The shell models interactive content as a **logical path tree** — relationship-aware routing for content *inside* one root surface, never concurrent overlays. The one global slot (`activeOverlay` + `activeScreenName`) and the shared 50 ms timer are unchanged.

```text
root
└── right-control-center
    ├── wifi
    ├── bluetooth
    ├── audio
    │   └── device-panel (reserved descendant shape; current panel remains content)
    └── notifications
```

Normative transitions:

- **Same path on the same screen toggles closed.**
- **A sibling path switches local content** in place — it preserves the root overlay and its screen ownership and does not restart the 50 ms timer.
- **A descendant path preserves its parent** and opens the child content inside the owning surface.
- **A different root or a different screen closes globally first**, then opens through the shared timer.
- **Rapid pending requests replace one another** — never a queue of duplicate opens.
- **Child components emit intent upward; the coordinator owns relation decisions.**

These paths live in `shell.qml`'s `overlayManager` (`activeSection`, the derived `activePath`, and the `rightControlCenterPath()` helper), so no visual component hardcodes path literals. Concurrent parent/child overlays remain out of scope. Full contract: `specs/overlay-manager.md` and `odd/tasks/interaction-tree-routing.md`.

### Implementation

- Coordination lives in `shell.qml` — components signal up, never communicate directly
- **Layer reservation:** the compositor's highest layer belongs to transient system feedback — notification toasts and the volume/brightness OSD. Everything the user opens and interacts with sits one layer below it, so feedback is never hidden behind a panel and panels never compete with it for attention. This is a protocol constraint rather than a visual preference: the compositor has no "bring to front" for shell surfaces, so the only reliable ordering is the layer each surface is born in.
- A **50ms Timer** before opening a new overlay avoids Wayland serial conflicts — exactly one shared timer for the session, never one per bar
- `Escape` closes the currently active overlay
- Notification toasts and the OSD are **not** managed overlays: passive `Overlay`-layer surfaces that never take keyboard focus

### The overlay slot (current and planned)

One slot, many requesters. These are surfaces that would occupy the slot, not groups that share it.

| Surface | State | Notes |
| ------- | ----- | ----- |
| Launcher | Implemented | Opens on the focused monitor; dismiss-click routing can hand off to PowerMenu or the MPRIS popup |
| PowerMenu | Implemented | Pinned to the requesting bar's screen |
| MPRIS popup | Implemented | Reachable only through launcher outside-click routing |
| Center dashboard (`center-panel`) | Implemented | Expands the bar's own center notch in place |
| Right control center | Implemented | One surface hosting the Wi-Fi / Bluetooth / Audio / Notifications cards and the nested audio device panel |
| Calendar | Planned | Would request the slot like any other overlay; see `specs/calendar.md` |
| Settings GUI | Planned | Same; see `specs/settings-gui.md` |
| Metrics dropdown | Dormant | Instantiated per bar with no open trigger |

---

## Notification Sounds

Sounds map to urgency level using freedesktop audio:

| Urgency  | Sound file                |
| -------- | ------------------------- |
| Low      | `message-new-instant.oga` |
| Normal   | `dialog-information.oga`  |
| Critical | `dialog-error.oga`        |

Sound can be muted independently of notifications via IPC: `quickshell ipc call notifications toggleSound`

---

## Design Token System

`Colors.qml` remains a `pragma Singleton` with readonly color and font-family properties. `Theme.qml` is the mutable structural-token singleton.

**Current architecture:**

- `theme/Theme.qml` — mutable singleton that exposes configurable structural tokens (radii, spacing, opacity, bar/dashboard geometry, animation durations, and font sizes)
- `~/.config/quickshell/config.json` — persists user preferences and is read on startup
- Hot-reload via Quickshell's `FileView` — changes apply without restarting
- Components use `Colors.*` for palette/font families and `Theme.*` for structural values

### Token categories

```
Theme.radius.sm / md / lg / pill
Theme.spacing.xs / sm / md / lg
Theme.opacity.surface / overlay / dim
Theme.bar.height / chipHeight / curveRadius / wrapDepth / style / screens / notchGapWidth / notchDepthRatio
Theme.dashboard.railWidth / bodyRadius / bodyOpacity / bodyBorderWidth / bodyPadding
Theme.dashboard.tabHeight / tabSpacing
Theme.dashboard.cardHeight / cardGap / progressHeight / progressRadius / sparklineWidth / sparklineHeight / footerHeight
Theme.panel.accentSeamWidth / secondarySeamWidth / volumeTrackHeight
Theme.rightPanel.opacity
Theme.island.chipRadius / activeFillOpacity / stateLayerHoverOpacity / stateLayerPressedOpacity
Theme.island.semanticGap / separatorWidth / powerTintOpacity
Theme.tab.paddingH / paddingV / radius / collapsedHeight
Theme.anim.fast / normal / slow / scale
Theme.font.caption / label / body / bodyLg / icon
Theme.debug.visualBounds / borderColor / borderWidth / barSilhouette
```

---

## Planned: Settings GUI

A floating overlay panel (centered, compact — not fullscreen) that exposes all `Theme.*` tokens as interactive controls. Inspired by Ambxst's settings panel.

The user should be able to change:

- Color palette / individual accent colors
- Font family per role
- Spacing density
- Border radius preset or custom
- Blur intensity
- Which widgets are visible in the bar
- Bar position (top/bottom)
- Animation speed / behavior
- Notification sound on/off per urgency

Changes write to `config.json` and apply live via hot-reload.
