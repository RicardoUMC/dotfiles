# Native island blur on all connected screens

## Goal
Make the validated native island blur apply automatically to every connected screen that has a Bar instance, without hard-coding monitor names.

## Scope
- Keep `surface.islandNativeBlur` as the global enable/disable switch.
- Remove the exact `surface.islandNativeBlurScreen` selector from active behavior and configuration.
- Reuse the existing `Quickshell.screens`/`Variants` screen model so hot-plugged monitors receive the same behavior automatically.
- Preserve the independent right-control-center blur and fail-safe global disable.

## Acceptance criteria
- Every enabled Bar instance applies the native island blur when the global switch is true.
- Monitor names, indices, ordering, and the current DP-1 identity are not referenced by island blur routing.
- Adding/removing a connected monitor follows the existing `Quickshell.screens` model without a manual selector update.
- `surface.islandNativeBlur=false` disables island geometry on every monitor.
- Documentation describes the all-connected-screen behavior and the global opt-out.
- Qt6 lint, JSON validation, diff check, soft reload, and log verification pass; current live host exposes DP-1 and DP-2.

## Tasks
1. [x] Remove the fixed-screen gate from Bar and Theme configuration.
2. [x] Update config and documentation for connected-screen behavior.
3. [x] Verify static and live behavior, then review the work unit.

## Evidence
- `Bar.qml` now gates island blur only on glass mode, global native blur, and `Theme.islandNativeBlur`; each existing Bar Variant therefore receives the same behavior without screen-name routing.
- `Theme.qml` no longer exposes or parses `surface.islandNativeBlurScreen`; `config.json` no longer contains that selector.
- `AGENTS.md`, `DESIGN.md`, and the correction task describe the global opt-out and the bounded approximation/RCC independence.
- Verification: JSON validation, Qt6 lint for `Bar.qml`, `Theme.qml`, and `IslandBlurRegion.qml`, and `git diff --check` passed. Soft reload produced `Configuration Loaded` with no subsequent `ERROR`; `/tmp/native-blur-all-screens.png` was captured successfully. Live verification covered the two currently connected monitors, `DP-1` and `DP-2`; hot-plug behavior was not exercised live.
- Structural guarantee: every `Bar` created by the existing `Quickshell.screens`/`Variants` model receives the same global blur gate, so future connected screens follow the same path without monitor-name routing.
- Work-unit commit: `063d1ee` (`feat(quickshell): apply island blur to connected screens`). Native review lineage `review-e019e06c3b764e27` approved and acknowledged; its coverage warning is addressed by this evidence distinction.

## Non-goals
- Do not change Bar screen selection (`bar.screens`).
- Do not alter RCC blur, visible masks, input masks, or overlay routing.
- Do not promote `IslandNativePrototype.qml`.
