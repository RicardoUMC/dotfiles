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

**Why SF Pro:** chosen over Geist and Outfit for the "premium software" feel. SF Pro Text for UI consistency, SF Pro Display for typographic hierarchy. Geist is installed but not used in the UI.

### Mutable structural tokens

`Theme.qml` exposes runtime-tunable structural values. Current bar-specific tokens include:

| Token | Default | Current config | Use |
| ----- | ------- | -------------- | --- |
| `Theme.barHeight` | `37` | `37` | Base top-bar offset used by overlays. |
| `Theme.barChipHeight` | `26` | `26` | Uniform chip height for workspace pills, metrics, and power button. |
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
| `Theme.barStyle` | `"silhouette"` | `"silhouette"` | Enables the masked wrapped silhouette; `"plain"` disables it. |

Debug scaffolding is also configurable through `debug.*` keys. `debug.barSilhouette` intentionally remains available for high-contrast silhouette tuning and should only be disabled when Ricardo explicitly requests it.

Dashboard body, rail, card, progress, sparkline, and footer geometry is configurable through the flat `Theme.dashboardXxx` properties above and the `dashboard.*` group in `config.json`. Defaults intentionally preserve the current center-dashboard visuals; large overrides may need proportional width/height tuning because the expanded notch remains bounded by `Theme.centerExpandedWidth` and `Theme.centerExpandedHeight`.

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

### Accent Borders

Cards and panels may use a **single-side color highlight** (left border) to create visual hierarchy without adding noise. Color matches the contextual accent (urgency color for notifications, `base0D` blue for general panels).

### Bar Style

**Wrapped floating silhouette** — not full-width. The bar is composed of independent left, center, and right islands with transparent gaps, anchored to the top of the screen. Inspired by macOS Sonoma / Ax-Shell and adapted from Ambxst's mask-composition idea.

The accepted silhouette design uses one fill surface clipped by a composite mask:

- `NotchIslandMask` defines each separated island and its gap-facing top corner pieces.
- `NotchCornerMask` draws explicit curved mask pieces, including lateral downward wrap pieces.
- `exclusiveZone` reserves only the interactive/content height; decorative wrap depth can draw below it without reserving the full visual height.
- Side islands share `sideTabHeight`, while chips use `Theme.barChipHeight` for consistent internal rhythm.
- The center island expands in place into the dashboard. Its expanded body overlays app content and does not increase Hyprland reserved space.
- The expanded center notch hosts a small dashboard body with a vertical tab rail adapted from the Ax-Shell expandable-dashboard direction: Media preserves the existing MPRIS controls, while Metrics shows live CPU/RAM/GPU cards with progress bars, Canvas sparklines, and a single compact `DSK | NET | VOL` footer row.
- Metrics cards use contextual per-metric colors (`base09` orange for CPU, `base0D` blue for RAM, `base0E` magenta for GPU) and disabled muted treatment for unavailable GPU data. Disk/network/volume remain compact footer readouts for this first slice.
- Deferred metrics work: temperatures, multi-GPU presentation, zoom/refresh controls, charts libraries, and external/Python monitor processes are intentionally out of scope.
- Compact center media-chip clicks now select the dashboard Media tab and open the in-place center dashboard, keeping media interaction inside the expanded center notch.
- The standalone MPRIS popup remains available for launcher fallback and future explicit triggers, but it is no longer the visible compact-chip click behavior.

---

## Overlay System

Full spec: overlays follow a **contextual focus and exclusivity** model.

### Exclusivity rules

- Overlays from **different context groups** close automatically when another incompatible overlay opens
- Overlays from the **same context group** (e.g. a submenu inside a panel) can coexist
- Secondary overlays inherit their parent's context — opening them does not close the parent

### Close triggers

An exclusive overlay must close when:

- Click outside its interactive area
- Another incompatible overlay takes focus
- `Escape` is pressed
- Global focus is lost (workspace change, window switch)
- Explicit close action

### Activation rules

- Overlays open/close **only on explicit user interaction**
- Hover must **never** open, close, or replace any overlay
- This prevents: accidental focus changes, interruptions during repeated clicks, involuntary activations between close elements

### Hierarchy

- Closing a parent overlay closes **all its descendants**
- Opening sibling overlays closes only the incompatible subtree
- Keyboard navigation respects the contextual hierarchy

### Implementation

- Coordination lives in `shell.qml` — components signal up, never communicate directly
- A **50ms Timer** before opening a new overlay avoids Wayland serial conflicts
- `Escape` closes the currently active overlay

### Context groups (current)

| Group           | Members                                                                  |
| --------------- | ------------------------------------------------------------------------ |
| `bar-primary`   | Launcher, PowerMenu, MPRIS popup, Calendar (planned), Settings (planned) |
| `bar-secondary` | Submenus and nested panels within a primary overlay                      |

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
Theme.bar.height / chipHeight / curveRadius / wrapDepth / style
Theme.dashboard.railWidth / bodyRadius / bodyOpacity / bodyBorderWidth / bodyPadding
Theme.dashboard.tabHeight / tabSpacing
Theme.dashboard.cardHeight / cardGap / progressHeight / progressRadius / sparklineWidth / sparklineHeight / footerHeight
Theme.tab.paddingH / paddingV / radius / collapsedHeight
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
