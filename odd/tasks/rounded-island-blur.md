# Restore native blur for curved bar islands

## Goal
Restore native `BackgroundEffect.blurRegion` blur for the custom bar islands without square artifacts at notch or wrap corners. Keep the existing GPU masks as the visible silhouette and preserve input, routing, focus, Escape, services, and multi-monitor behavior.

## Tasks
1. Replace rectangular island blur geometry with a protocol-compatible scanline rasterization that emits a union of narrow rectangles matching the island silhouette.
2. Keep the right-control-center body blur unchanged and keep fallback translucent fills active.
3. Run Qt 6 lint, JSON/diff checks, soft reload verification, and a live screenshot comparison focused on notch corners.
4. Run native review for the new candidate and record the outcome.
5. Align blur scanline geometry with the authoritative island mask's shared corner equations and pixel-boundary rules. (implemented in the second correction)
6. Re-run visual verification and native review for the alignment correction.
7. Test a dedicated Hyprland layer namespace/rule using compositor alpha-aware blur for the rendered bar surface, while retaining a reversible native/translucent fallback.
8. Verify the compositor experiment and review the new candidate.
9. Roll back the fullscreen compositor blur experiment after the observed interaction latency regression.
10. Verify rollback performance and preserve the bounded native/translucent baseline.
11. Disable scanline island blur as the stable baseline after expansion latency and edge artifacts persisted.
12. Verify the stable island baseline after reload.
13. Gate disabled scanline rebuilds so islandNativeBlur=false avoids dynamic Region churn.
14. Verify center expansion after the rebuild gate.

## Non-goals
- No changes to services, IPC, routing, focus, Escape, input masks, overlay ownership, or monitor selection.
- No compositor configuration changes or fullscreen blur workaround.
- No commit or delivery without explicit user authorization.

## Acceptance criteria
- Glass mode enables native blur for island surfaces through bounded rectangle unions.
- Blur geometry is independent from the existing visual and input masks.
- No new square/rectangular halos are visible at notch joins in the live compositor capture.
- Solid/translucent fallback behavior remains unchanged.
- Existing right-control-center blur continues to use its rounded Region.

## Evidence
- Ghostty PR #10727 uses central rectangle plus per-row scanline rectangles for rounded blur regions.
- Quickshell PR #566 confirms `Region` is rasterized to `QRegion` and supports per-corner radii, but the protocol remains rectangle-only.
- Hyprland 0.56 implements `ext-background-effect-v1` with client-controlled `wl_region` rectangles.
- Implementation uses `IslandBlurRegion.qml` to generate one-pixel rectangle slices for each island body and wrap, while `NotchIslandMask` and the hit mask remain unchanged.
- `Bar.qml` now includes three bounded island blur regions plus the existing rounded right-control-center body region.
- Qt 6 lint passed for the changed QML; soft reload reached `Configuration Loaded` with no `ERROR`; `git diff --check` passed. Live `grim` capture showed no obvious square blur halos at either monitor's notch corners.
- Native review lineage `review-11a4ee9286814235` approved and acknowledged. Informational warnings: stale corner flags at `IslandBlurRegion.qml:106-113` and unproved blur boundary at `Bar.qml:53-55`; neither opened a correction.

## Alignment correction evidence
- Added `IslandGeometry.qml` as a shared analytic helper for quarter-circle boundaries and integer pixel intervals.
- `IslandBlurRegion.qml` now tracks corner, wrap, height, and section-state changes before rebuilding its rectangle union.
- Qt 6 lint, `git diff --check`, JSON parsing, and soft reload passed; latest reload reached `Configuration Loaded` with zero ERROR/WARN diagnostics.
- Live `grim` capture showed no obvious rectangular halos at collapsed notch/wrap joins on either monitor. Pixel-perfect parity remains limited by the protocol's hard rectangle geometry and downscaled screenshot contrast.
- Alignment correction native review lineage `review-d79c9103c196b5e9` was approved and acknowledged. Informational warnings only: bottom-rounding transition and corner-transition coverage; no correction was opened.

## Compositor experiment (rolled back)
- Hyprland 0.56.2 was tested with global blur enabled (`size=3`, `passes=1`, `xray=false`) and a dedicated `tokyo-bar` namespace matched by one alpha-aware `hl.layer_rule` (`blur = true`, `ignore_alpha = 0.2`).
- The experiment set `surface.islandNativeBlur: false` to avoid double-blurring the islands. RCC native blur, translucent fills, visual/input masks, routing, focus, Escape, services, and monitor routing were unchanged.
- Verification passed: Qt6 lint, Lua parse, JSON parse, diff check, `hyprctl reload config-only`, and Quickshell soft reload. `configerrors` was empty; both DP-1 and DP-2 reported the `tokyo-bar` Top-layer namespace. The screenshot comparison showed no proven visual improvement.
- Native review lineage `review-f0e61e646ae3341a` approved and acknowledged. Informational warnings only: compositor blur policy and bottom-rounding coverage; no correction was opened.

## Rollback evidence
- The fullscreen compositor blur experiment was rolled back by explicit user choice after the latest recording showed central interaction/render latency.
- The dedicated `tokyo-bar` layer rule and Bar namespace were removed, and `surface.islandNativeBlur` was restored to `true`.
- The user then selected the stable baseline: disable only `surface.islandNativeBlur` so custom islands retain their exact translucent masks while the rounded right-control-center blur remains enabled.
- Stable-baseline verification: JSON parsing and `git diff --check` passed; Quickshell soft reload reached `Configuration Loaded` with no subsequent `ERROR`; Qt6 lint reported only known Quickshell/blur-region type-resolution warnings; `/tmp/quickshell-recordings/island-native-disabled.png` showed smooth island contours without obvious square QRegion artifacts. RCC blur remains configured independently but was closed during the no-click capture, so its rendered blur was not directly re-verified.
- Native review `review-106dd13f512a0a5b` was approved and acknowledged. Informational findings only: bottom-rounding direction and disabled rasterization; no correction was opened.
- The disabled-rebuild gate was verified with Qt6 lint, JSON parse, `git diff --check`, and soft reload. Quickshell reached `Configuration Loaded` with no subsequent `ERROR`; `/tmp/quickshell-recordings/island-native-disabled-gated.png` showed smooth contours on both displays. Native review `review-8e006062e7c81570` was approved and acknowledged; the inactive rasterization warning was informational only.
- Work-unit commit: `eb5231b` (`fix(quickshell): smooth center island expansion`).

- IslandGeometry/IslandBlurRegion, RCC native blur, visual/input masks, routing, focus, Escape, services, and multi-monitor behavior remain unchanged. The bounded native/translucent baseline is active.
- Live verification: `hyprctl reload config-only` returned `ok`; `hyprctl configerrors` was empty before and after the soft reload; both monitors changed from `tokyo-bar` to the normal `quickshell` Top surfaces; Quickshell ended with `Configuration Loaded` and no `ERROR`; the rollback screenshot is `/tmp/quickshell-recordings/rollback-baseline.png`.
- Static verification passed: Qt6 `qmllint` with only documented Quickshell/blur-region warnings, `luac -p`, JSON parse, `git diff --check`, and repository/active Hyprland config identity. Responsiveness was not measured by interaction because verification avoided clicks and service mutations; the fullscreen blur path is nevertheless no longer active.

## Rebuild gate correction
- `IslandBlurRegion` now imports `Theme.islandNativeBlur` directly and gates its rebuild path. Disabling native island blur destroys generated scanline slices once, then ignores geometry/state-triggered rebuilds while disabled; re-enabling clears the gate and rebuilds the same scanline geometry normally.
- The gate is deliberately limited to generated blur regions. Visual Canvas/MultiEffect masks, the input mask, RCC rounded native region, routing, focus, Escape, services, animation timing, BarSection layers, and multi-monitor behavior are unchanged.
- This is a lifecycle/churn fix only: all existing geometry equations and pixel-boundary calculations remain untouched.
- Focused Qt 6 lint and `git diff --check` are the applicable static checks for this correction; runtime/live verification remains the parent task's responsibility.
