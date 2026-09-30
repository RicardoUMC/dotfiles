# Settings GUI

**Status:** Planned
**Files:** none — no implementation exists

> **Implementation note:** As of this spec's writing there is **no settings panel code anywhere in the repository** — no QML component, no IPC target, no keybind. Everything below restates or derives from the "Planned: Settings GUI" section in `DESIGN.md` and the token architecture that already exists; none of it is an approved implementation decision.

## Description
A floating overlay panel — centered and compact, not fullscreen — that exposes the shell's design tokens as interactive controls, so the look can be changed without editing `config.json` by hand. It is a **planned** overlay: when built, it would request the shell's single global overlay slot through `shell.qml`, one at a time with every other managed surface. Inspired by Ambxst's settings panel, subject to the reference-first workflow in `AGENTS.md` (study the pattern, adapt to this shell, do not copy files).

## Grounded in existing architecture

The panel's natural data surface already exists:

- **`theme/Theme.qml`** — mutable structural-token singleton: `radius.*`, `spacing.*`, `opacity.*`, bar geometry (`barHeight`, `barChipHeight`, `barCurveRadius`, `barWrapDepth`, `centerCollapsedWidth`, `centerExpandedWidth/Height`, `barStyle`, notch gap/depth ratios), tab/island/ornament variants, `dashboard.*` group (rail, body, tab, card, progress, sparkline, footer), `panel.*` (accent seam, volume track), `rightPanel.opacity`, `anim.*`, `font.*` sizes, and `debug.*` flags.
- **`config.json`** — flat JSON groups (`radius`, `spacing`, `opacity`, `bar`, `dashboard`, `panel`, `anim`, `font`, `rightPanel`, `debug`) that `Theme.qml` reads via `FileView` with 100 ms-debounced hot-reload. A GUI that writes this file inherits live application for free.
- **`theme/Colors.qml`** — `pragma Singleton` with **readonly** palette and font-family tokens (Tokyo City Terminal Dark / Base16). It has no config.json path today; exposing it is an architecture change, not a UI change (see open questions).

## Intended capabilities (from DESIGN.md, verbatim scope)
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

**Gap note:** several listed items have **no backing token today** — palette and font families are readonly `Colors.qml` values; bar widget visibility, bar position, and per-urgency sound toggles are not expressed in `config.json`; "blur intensity" exists only as `island.blur` in the unused Variant-A island group. These are requirements to build toward, not current capabilities.

## Relationship to overlay rules
- Must follow the `shell.qml` coordination described in `specs/overlay-manager.md`: exclusivity is **session-global**, so opening settings closes whatever overlay was active, on any screen; `Escape` and click-outside close it; a workspace or window change dismisses it; every open goes through the one shared 50 ms anti-serial-conflict timer; it opens only on explicit user interaction. There are no context groups — settings is simply another name in the single `activeOverlay` slot.
- Sub-panels inside the settings surface (a token group expanding, a nested picker) are **content of that one overlay**, the way the nested audio device panel is content of `RightControlCenter`, so they neither need nor get a second slot and cannot close their parent.
- Per `AGENTS.md`, any new tokens it exposes must be documented in `DESIGN.md`, `AGENTS.md`, and relevant `specs/*.md` via `sync-docs`.

## Open design questions (unresolved — do not treat as decided)
1. **Trigger.** No keybind, bar control, or IPC command exists or is approved. Launcher/PowerMenu patterns show the shape only.
2. **Surface form.** Compact centered overlay conflicts with the center island owning that screen region; where the panel sits and how it avoids the notch is undecided.
3. **Write path.** Edit `config.json` directly (round-tripping user comments/formatting?), or through a dedicated IPC handler in `shell.qml`? Neither is chosen.
4. **Colors/fonts.** Making readonly `Colors.qml` values configurable requires deciding a new mutable-token mechanism; the "keep color and font families in `Colors.qml`" convention may need an explicit amendment from Ricardo.
5. **Advanced vs simple mode.** Presets/scales (radius sm/md/lg) versus free numeric editing of every token; risk of token sprawl per `AGENTS.md`.
6. **Validation/limits.** What ranges are legal per token, and what happens on out-of-band `config.json` edits while the panel is open.
7. **Widget visibility & bar position.** These are structural shell changes (which bar sections render, top vs bottom anchoring) that likely precede the GUI; sequencing is undecided.

## Non-goals (current)
- No fabricated component names, file paths, IPC targets, or keybindings.
- No claim that any token is "exposed in settings" until both the token and the panel exist.
