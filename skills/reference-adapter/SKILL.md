---
name: reference-adapter
description: "Trigger: adapt UI reference, inspect Ambxst, inspect Ax-Shell, inspect Dank Material Shell, reference-inspired Quickshell design. Extract intent and patterns from UI references, compare alternatives, and adapt them to this Tokyo City shell without copying wholesale."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract
Use this skill before adopting any idea from Ambxst/Ax-Shell, Dank Material Shell, screenshots, prototypes, or another UI shell reference for this Quickshell/QML Tokyo City dotfiles project.

## Hard Rules
- Treat references as inspiration, not source material to copy or vendor.
- Preserve this project architecture: `shell.qml` coordinates state, components signal upward, and overlays remain explicitly opened.
- Keep colors and font families in `Colors.qml`; keep mutable structure in `Theme.qml` and `config.json` when the knob is broadly useful.
- Avoid token sprawl; do not add one-off decorative tokens without clear tuning value.
- Never expand scope from reference inspection into implementation unless explicitly authorized.

## Decision Gates
- If the reference cannot be inspected, state the limitation and proceed only with clearly marked assumptions.
- If copying would be required to preserve the effect, reject the approach and propose an adapted pattern.
- If the idea changes overlay ownership, input routing, or state coordination, require an architecture decision before implementation.

## Execution Steps
1. Identify the reference, target feature, and specific behavior or visual pattern under consideration.
2. Inspect how the reference expresses intent, state, motion, spacing, and interaction.
3. Extract reusable principles, not code or file structure.
4. Compare at least one alternative approach in this project, with concise pros and cons.
5. Recommend the adaptation that best fits Quickshell/QML, Tokyo City styling, and existing overlay rules.

## Output Contract
Return a concise adaptation brief: reference inspected, intent extracted, alternatives compared, recommended approach, risks, and implementation boundaries.

## References
- `AGENTS.md`
- `DESIGN.md`
- `quickshell/.config/quickshell/shell.qml`
- `quickshell/.config/quickshell/theme/Colors.qml`
- `quickshell/.config/quickshell/theme/Theme.qml`
