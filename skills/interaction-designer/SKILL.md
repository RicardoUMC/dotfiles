---
name: interaction-designer
description: "Trigger: design UI flow, define overlay behavior, plan nested panel, plan detail panel, specify Escape behavior, specify focus behavior, motion before implementation. Defines Quickshell interaction states and transitions before code changes."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract
Use this skill before implementing or revising UI flows, overlay behavior, nested/detail panels, click handling, Escape handling, focus behavior, motion, or state composition in this Quickshell/QML Tokyo City shell.

## Hard Rules
- Define behavior and visual composition before implementation.
- Overlay coordination belongs in `shell.qml`; child components signal intent upward.
- Open overlays only through explicit user interaction; never open on hover.
- Escape closes the active overlay; nested content is inside the owning surface, so closing that surface tears down its expanded sections with it — there is no separate child overlay to cascade.
- Overlay exclusivity is a **single global slot** (`activeOverlay` + `activeScreenName`): opening any overlay closes the active one, on any screen. There are no context groups; do not design against a `bar-primary`/`bar-secondary` model. See `specs/overlay-manager.md`.
- Treat minimalism as edited and intentional, not empty, flat, generic, or under-designed.
- Preserve Tokyo City dark terminal character and Ambxst/Ax-Shell/Dank-inspired ambition without copying.
- Keep motion purposeful, short, and supportive of state comprehension.

## Decision Gates
- If ownership of state is unclear, stop and assign it before implementation.
- If nested panels can conflict with global overlays, define close order and exclusivity first.
- If focus, click-outside, or keyboard behavior is ambiguous, resolve those states before code.
- If a state appears too simple, explicitly decide whether restraint is appropriate or the surface needs more hierarchy, density, grouping, layering, silhouette, curve, or accent.
- If the flow requires new structural sizing, decide whether it belongs in `Theme.qml` and `config.json`.

## Execution Steps
1. Name the user goal and entry points.
2. Enumerate states, including collapsed, focused, expanded, nested, loading, empty, error, and closing states where relevant.
3. Specify each state's visual composition: hierarchy, density, grouping, layered surfaces, rhythm, whitespace, accents, and useful asymmetry.
4. Define transitions, triggers, blocked transitions, and close behavior.
5. Specify click, click-outside, Escape, focus, keyboard, and pointer behavior.
6. Identify required signals, state owners, and integration points in `shell.qml`.
7. List token needs for layout, spacing, radius, dimensions, opacity, accents, silhouettes, curves, and timing.

## Output Contract
Return a concise interaction spec: goals, state composition table, transition rules, input behavior, state ownership, token needs, and implementation notes.

## References
- `AGENTS.md`
- `DESIGN.md`
- `quickshell/.config/quickshell/shell.qml`
- `quickshell/.config/quickshell/bar/CenterPanel.qml`
- `quickshell/.config/quickshell/theme/Theme.qml`
