---
name: visual-critic
description: "Trigger: review screenshot, critique prototype, visual hierarchy review, spacing critique, Tokyo City fit check, UI polish pass. Reviews Quickshell visuals without implementing fixes."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract
Use this skill to review screenshots, prototypes, or described UI states for visual hierarchy, spacing, density, contrast, alignment, curve quality, noise, and Tokyo City fit.

## Hard Rules
- Do not implement fixes or edit files.
- Critique the visible result, not the author.
- Anchor feedback in this project's Tokyo City palette, Quickshell/QML constraints, and existing design language.
- Prefer high-impact issues over exhaustive nitpicks.
- Separate observed problems from uncertain guesses when a screenshot lacks context.

## Decision Gates
- If no image or concrete UI description is available, request one focused artifact before critique.
- If contrast or spacing cannot be judged from the artifact, mark it unverified.
- If a proposed fix implies new tokens, call out whether it is high-leverage or token sprawl.
- If the issue is interaction-dependent, hand off to interaction design instead of guessing.

## Execution Steps
1. Identify the screen, state, and intended user focus.
2. Review hierarchy, grouping, alignment, rhythm, density, and whitespace.
3. Review contrast, color temperature, icon/text legibility, and Tokyo City palette fit.
4. Review corner radii, curves, silhouettes, shadows, borders, and visual noise.
5. Prioritize findings by user impact and confidence.
6. Suggest concise design directions without writing implementation code.

## Output Contract
Return a concise visual critique: strengths, prioritized issues, recommended direction, confidence notes, and non-goals. Do not include patches.

## References
- `AGENTS.md`
- `DESIGN.md`
- `quickshell/.config/quickshell/theme/Colors.qml`
- `quickshell/.config/quickshell/theme/Theme.qml`
