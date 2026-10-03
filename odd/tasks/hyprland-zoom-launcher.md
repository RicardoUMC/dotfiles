# Hyprland smooth zoom and Super launcher

## Goal
Fix the Hyprland mouse-wheel zoom bindings so zoom changes incrementally and smoothly, and allow the launcher to toggle with Super alone.

## Tasks
- [x] Add a stateful incremental zoom helper and wire wheel bindings in both Hyprland config formats.
- [x] Add a Super-only launcher release binding in both Hyprland config formats.
- [x] Run configuration/syntax checks and inspect the resulting diff.

## Constraints
- Preserve existing Space launcher binding as a fallback.
- Keep zoom bounded and reset-safe.
- Do not commit without explicit user authorization.
