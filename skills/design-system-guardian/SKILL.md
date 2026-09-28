---
name: design-system-guardian
description: "Trigger: before closing UI change, design system check, token usage check, qmldir check, overlay rules check, docs sync check. Verifies Quickshell UI changes against this project's design system before handoff."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract
Use this skill before closing Quickshell/QML UI changes in this dotfiles project, especially changes touching layout, colors, fonts, overlays, QML component types, or design documentation.

## Hard Rules
- Colors and font families must come from `Colors.qml`; do not hardcode them in components.
- Mutable structure belongs in `Theme.qml` and `config.json` when it is a high-leverage tuning knob.
- Avoid token sprawl; reject one-off decorative configuration unless it materially improves tuning.
- Register every new local QML type in the appropriate `qmldir`.
- Preserve overlay rules: `shell.qml` coordinates, explicit interaction only, no hover-open, Escape closes the active overlay.
- Keep implementation, specs, `DESIGN.md`, and `AGENTS.md` consistent when tokens or behavior change.

## Decision Gates
- If a new QML type lacks `qmldir` registration, block closure until fixed.
- If colors, fonts, or structural values bypass the token system, require correction or a documented exception.
- If overlay behavior bypasses `shell.qml` coordination, require redesign.
- If docs/specs are stale after a design-system change, require sync before closure.

## Execution Steps
1. Identify the changed UI surfaces and new QML types.
2. Check color, font, spacing, size, radius, opacity, and motion values against `Colors.qml`, `Theme.qml`, and `config.json`.
3. Check overlay ownership, close behavior, explicit interaction, and parent-child coordination.
4. Check `qmldir` registration for new local components.
5. Check `DESIGN.md`, `AGENTS.md`, and relevant `specs/*.md` for required updates.
6. Report pass/fail findings with concrete file references.

## Output Contract
Return a concise closure report: pass items, blocking issues, non-blocking improvements, docs/spec sync status, and files or behaviors needing review.

## References
- `AGENTS.md`
- `DESIGN.md`
- `specs/`
- `quickshell/.config/quickshell/qmldir`
- `quickshell/.config/quickshell/shell.qml`
- `quickshell/.config/quickshell/theme/Colors.qml`
- `quickshell/.config/quickshell/theme/Theme.qml`
- `quickshell/.config/quickshell/config.json`
