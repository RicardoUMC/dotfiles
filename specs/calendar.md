# Calendar

**Status:** Planned
**Files:** none — no implementation exists

> **Implementation note:** As of this spec's writing, there is **no calendar code anywhere in the repository**. `grep` across `quickshell/` and `hyprland/` for calendar/lunar-related terms returns nothing in the shell. Everything below is intent, grounded in `DESIGN.md` / `AGENTS.md` statements and the existing architecture; no decision has been made that Ricardo has not already made.

## Description
A calendar popup reachable from the clock. It is a **planned** overlay: when built, it would request the shell's single global overlay slot through `shell.qml` like every other managed surface — one overlay at a time across all screens, rendered on the screen that asked for it. The intended entry point is the bar clock (`bar/ClockChip.qml`, currently the center island's collapsed content); the click currently toggles the in-place center dashboard and does not reserve any calendar behavior.

## Known intent (from existing docs)
- `DESIGN.md` overlay model and `specs/overlay-manager.md`: opening a calendar would close whatever overlay was active — on any screen — `Escape` would close it, dismissal would also follow a click outside or a workspace/window change, and nothing may open or close it on hover. There is no group to belong to; see `AGENTS.md` "Overlay system rules".
- `SPECS.md` index description: "Calendar popup from clock" — popup form, clock-anchored.
- Reference-first workflow (`AGENTS.md`): if inspired by Ambxst, inspect the reference, compare alternatives, then adapt the idea to this shell's architecture — do not copy.

## Relationship to existing architecture
- Overlay coordination would live in `shell.qml` (components signal up, never talk to each other directly); a calendar would be registered as another name in the single `overlayManager` slot alongside `launcher`, `powermenu`, `mpris`, `center-panel`, and `right-control-center`, opened behind the shared 50 ms anti-serial-conflict timer.
- A popup, rather than expansion inside an existing surface, is what makes it an overlay transition at all: nested content inside an already-open surface (the audio device panel, a control-center section card) is not an overlay and never displaces one. This is the distinction the retired context-group language used to blur.
- If it needs a trigger surface, it competes with the existing center-island click (in-place dashboard toggle) — this collision is an open question, not a solved design.
- Layout values must come from token infrastructure: structural geometry from `Theme.qml` (existing `radius.*`, `spacing.*`, `opacity.*` categories) and palette/fonts from `Colors.qml` (`Colors.uiFont`, `Colors.displayFont`, `Colors.monoFont`) — no hardcoded families.
- Any hot-reloadable user settings would go through `Theme.qml` + `config.json`, following the configurability-first UI rule.

## Open design questions (unresolved — do not treat as decided)
1. **Trigger.** Clock click conflicts with the center dashboard toggle. Does the calendar open on the same click, a second click / long-press, a separate control, or as a new tab inside the expanded center dashboard rail (`Media` / `Metrics` already occupy it)?
2. **Surface form.** Floating popup anchored to the clock, part of the center notch, or a PowerMenu-style fullscreen `WlrLayer.Top` surface? None is chosen.
3. **Content scope.** Month grid only? Agenda/events? If events, from which source (local file, CalDAV, none) — no data source has been selected.
4. **Lunar / regional calendars.** Not stated in any existing doc; whether they belong here is entirely undecided.
5. **Navigation.** Whether month/year navigation, "today" jump, or keyboard interaction are in scope.
6. **Tokens.** Whether the calendar introduces a `calendar.*` group in `config.json` or reuses existing `radius`/`spacing`/`opacity` tokens — token-sprawl check required per `AGENTS.md`.
7. **IPC.** No IPC command name exists or is approved; the existing `quickshell ipc call ...` pattern shows the shape only.

## Non-goals (current)
- No fabricated keybinding, filename, component name, or IPC target — those will be decided during implementation planning.
- No assumed dependency (calendar libraries, daemons) has been approved.
