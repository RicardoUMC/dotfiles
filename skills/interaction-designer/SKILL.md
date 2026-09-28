---
name: interaction-designer
description: "Trigger: design UI flow, define overlay behavior, plan nested panel, plan detail panel, specify Escape behavior, specify focus behavior, motion before implementation. Defines Quickshell interaction states and transitions before code changes."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract
Use this skill before implementing or revising UI flows, overlay behavior, nested/detail panels, click handling, Escape handling, focus behavior, or motion in this Quickshell/QML Tokyo City shell.

## Hard Rules
- Define behavior before implementation.
- Overlay coordination belongs in `shell.qml`; child components signal intent upward.
- Open overlays only through explicit user interaction; never open on hover.
- Escape closes the active overlay; closing a parent closes its children.
- Preserve mutual exclusion between incompatible overlay context groups.
- Keep motion purposeful, short, and supportive of state comprehension.

## Decision Gates
- If ownership of state is unclear, stop and assign it before implementation.
- If nested panels can conflict with global overlays, define close order and exclusivity first.
- If focus, click-outside, or keyboard behavior is ambiguous, resolve those states before code.
- If the flow requires new structural sizing, decide whether it belongs in `Theme.qml` and `config.json`.

## Execution Steps
1. Name the user goal and entry points.
2. Enumerate states, including collapsed, expanded, nested, loading, empty, error, and closing states where relevant.
3. Define transitions, triggers, blocked transitions, and close behavior.
4. Specify click, click-outside, Escape, focus, keyboard, and pointer behavior.
5. Identify required signals, state owners, and integration points in `shell.qml`.
6. List token needs for layout, spacing, radius, dimensions, opacity, and timing.

## Output Contract
Return a concise interaction spec: goals, state table, transition rules, input behavior, state ownership, token needs, and implementation notes.

## References
- `AGENTS.md`
- `DESIGN.md`
- `quickshell/.config/quickshell/shell.qml`
- `quickshell/.config/quickshell/bar/CenterPanel.qml`
- `quickshell/.config/quickshell/theme/Theme.qml`
