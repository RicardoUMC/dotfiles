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
4. [x] Run lint, reload, capture, rollback, and native review.

## Implementation evidence

- `Theme.qml` resets `surface.islandNativeBlurScreen` to `""` on every config apply and accepts only a non-empty string.
- `Bar.qml` enables all three island regions only for `glass` + native blur + the exact matching `ShellScreen.name`; `IslandBlurRegion.qml` defaults disabled and preserves the fallback geometry. The retained opt-in now contributes one declarative interior rectangle per island; the former per-row scanline implementation is historical and no longer retained.
- Historical pilot configuration enabled the bounded pilot for `DP-1`; prototype selectors remain `none`/empty. The current configuration has the pilot disabled after rollback.
- Implementation commit: `ebe728c` (`feat(quickshell): pilot native island blur on DP-1`).
- Verification: JSON parse, Qt 6 `qmllint` (exit 0 with known warnings), `git diff --check`, `hyprctl configerrors`, and soft reload passed; reload reached `Configuration Loaded` with no `ERROR`.
- Live capture: `DP-1` captured at `/tmp/native-blur-pilot/DP-1.png`; `DP-2` was not connected, so its fallback was not visually captured. No visual blur claim is made from this capture.
- Native review: lineage `review-d58670c7db512f09` approved and acknowledged against the reduced candidate; one informational warning (`R3-pilot-coverage`) only.

## Acceptance criteria
- `islandNativeBlur` remains false unless explicitly enabled with a non-empty exact screen name.
- If explicitly re-enabled, only the matching Bar attaches the bounded interior blur region; the current default keeps all island native geometry disabled.
- DP-2 retains the translucent masked fallback.
- RCC blur, input masks, focus, routing, services, and multi-monitor behavior remain unchanged.
- Invalid or unplugged screen names enable no island blur.
- Static checks pass; live reload has no errors; visual evidence is reported conservatively.

## Rollback
**Applied:** Set `surface.islandNativeBlur` to `false` and `surface.islandNativeBlurScreen` to `""`. The translucent masked fallback is now the active baseline on every bar.

**Rationale:** Native scanline QRegion rebuilds caused expansion latency and shape mismatch during dashboard interaction. The retained opt-in was corrected to a no-churn interior-only rectangle per island, trading curved-edge and wrap coverage for bounded geometry. Keep it disabled and do not claim visual blur without new live evidence.
