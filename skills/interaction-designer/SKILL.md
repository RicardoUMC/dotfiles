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
- Treat repeated user feedback and accepted visual iterations as evolving preference evidence; keep uncertain preferences provisional and revise them when later feedback conflicts.
- For expandable content, prefer contextual inline placement directly below or beside its triggering row; do not append unrelated detail to the bottom of a panel.
- Preserve the right-island outer silhouette by default; refine its internal panels, icons, states, hierarchy, and density unless the user explicitly requests a new silhouette.

## Logical interaction tree (normative)

Interactive content is modeled as a **logical path tree**, not as concurrent overlay windows. The single global root overlay (`activeOverlay` + `activeScreenName`) and the one shared 50 ms open timer are unchanged; the tree describes how content *inside* a root surface relates to itself.

```text
root
└── right-control-center
    ├── wifi
    ├── bluetooth
    ├── audio
    │   └── device-panel (reserved descendant shape; current panel remains content)
    └── notifications
```

Every actionable implementation must honor these transitions:

- **Same path on the same screen toggles closed.**
- **A sibling path switches local content** in place — it preserves the root overlay and its screen ownership and does not restart the 50 ms timer.
- **A descendant path preserves its parent** and opens the child content inside the owning surface.
- **A different root or a different screen closes globally first**, then opens through the shared 50 ms timer.
- **Rapid pending requests replace one another** — a single pending slot, never a queue of duplicate opens.
- **Child components emit intent upward; the coordinator owns relation decisions.** No component-to-component calls.
- **Every actionable trigger must define, before implementation:** pointer hover and press, keyboard/focus, disabled state, loading/error state, repeated-click behavior, outside-click, `Escape`, and screen ownership. If any of these is ambiguous, stop and resolve it in the spec before writing code.

Full contract: `specs/overlay-manager.md` and `odd/tasks/interaction-tree-routing.md`.

## Decision Gates
- If ownership of state is unclear, stop and assign it before implementation.
- If nested panels can conflict with global overlays, define close order and exclusivity first.
- If focus, click-outside, or keyboard behavior is ambiguous, resolve those states before code.
- If a state appears too simple, explicitly decide whether restraint is appropriate or the surface needs more hierarchy, density, grouping, layering, silhouette, curve, or accent.
- If the flow requires new structural sizing, decide whether it belongs in `Theme.qml` and `config.json`.

## Execution Steps
1. Name the user goal and entry points.
2. Enumerate states, including collapsed, focused, expanded, nested, loading, empty, error, and closing states where relevant.
3. Specify each state's visual composition: hierarchy, density, grouping, layered surfaces, rhythm, whitespace, accents, useful asymmetry, and contextual placement of expanded content.
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
