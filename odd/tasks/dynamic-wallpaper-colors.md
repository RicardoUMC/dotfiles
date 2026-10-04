# Dynamic Wallpaper Colors — Documentation Task

**Status:** Design captured; implementation not started.

## Goal

Document a future global color-palette mode derived from the selected wallpaper, with an explicit user-selected fallback and review guidance requiring configurability checks.

## Scope

- [x] Add `specs/dynamic-colors.md`.
- [x] Update design/spec indexes and current-state notes where appropriate.
- [x] Add an AGENTS.md review rule requiring RDD and general applied-change reviews to inspect user configurability.
- [x] Keep the palette scope global for the session and separate color roles from structural tokens.

## Decisions

- `fixed`, `dynamic`, and `accent-only` are future conceptual modes.
- Dynamic colors apply one active palette globally across monitors for the session.
- The user chooses the fallback palette used when extraction fails or dynamic mode is unavailable.
- Tokyo City remains an available fallback, not a mandatory fallback.
- Structural tokens such as spacing, radii, geometry, and animation remain independent from dynamic color roles.

## Non-goals

- No wallpaper color extraction implementation.
- No changes to `Colors.qml`, `Theme.qml`, or runtime configuration.
- No commit or delivery action.
