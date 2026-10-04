# Configurable Bar — Documentation Task

**Status:** Design captured; implementation not started.

## Goal

Document a future shell-bar architecture that supports per-monitor position and visibility policies, preserves the current island ornaments, and allows the center dashboard to be embedded or detached.

## Scope

- Add a versioned specification for global defaults and per-monitor overrides.
- Define `top`, `bottom`, `left`, and `right` positions.
- Define `always`, `edge-reveal`, and `disabled` visibility modes.
- Keep shared monitor seams free of reveal hit regions.
- Preserve `islands` and `continuous` visual styles as separate composition choices.
- Define `embedded` and `detached` dashboard attachment modes.
- Synchronize design and architecture documentation without claiming future behavior is implemented.

## Tasks

- [x] Write `specs/configurable-bar.md`.
- [x] Update design/documentation indexes and current-state notes where appropriate.
- [x] Verify terminology and implementation-status boundaries.

## Non-goals

- No QML or configuration implementation.
- No changes to live bar behavior.
- No commit or delivery action.
