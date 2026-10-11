# Native island blur pilot

## Goal
Enable the existing `BackgroundEffect.blurRegion` island path for exactly one named monitor (`DP-1`) while preserving translucent fallback and all other bar behavior.

## Scope
- Add an exact-screen `surface.islandNativeBlurScreen` selector.
- Gate scanline region generation and composition on the selected Bar instance.
- Enable the pilot on `DP-1` only; keep other screens and prototype selectors disabled.
- Document rollback and verify static/runtime behavior without claiming visual blur until captures support it.

## Tasks
1. [x] Add exact-screen selector and fail-closed parsing.
2. [x] Gate island blur regions per Bar instance.
3. [x] Enable DP-1 pilot and document configuration contract.
4. [ ] Run lint, reload, capture, rollback, and native review.

## Implementation evidence

- `Theme.qml` resets `surface.islandNativeBlurScreen` to `""` on every config apply and accepts only a non-empty string.
- `Bar.qml` enables all three island regions only for `glass` + native blur + the exact matching `ShellScreen.name`; `IslandBlurRegion.qml` defaults disabled and preserves the fallback geometry.
- `config.json` enables the bounded pilot for `DP-1`; prototype selectors remain `none`/empty.
- Implementation commit: `ebe728c` (`feat(quickshell): pilot native island blur on DP-1`).

## Acceptance criteria
- `islandNativeBlur` remains false unless explicitly enabled with a non-empty exact screen name.
- With the pilot enabled, only the matching Bar generates island blur scanlines.
- DP-2 retains the translucent masked fallback.
- RCC blur, input masks, focus, routing, services, and multi-monitor behavior remain unchanged.
- Invalid or unplugged screen names enable no island blur.
- Static checks pass; live reload has no errors; visual evidence is reported conservatively.

## Rollback
Set `surface.islandNativeBlur` to `false` and `surface.islandNativeBlurScreen` to `""`, then reload the shell.
