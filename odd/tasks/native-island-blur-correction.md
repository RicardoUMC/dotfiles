# Native island blur correction

## Goal
Improve the island blur shape after live screenshots showed fluency returned but the five-band approximation remained visibly coarse. Keep the active one-screen configuration bounded: the fixed Region composition is intentionally enabled by default on DP-1 after live validation, while exact-screen selection protects other monitors.

## Context
- Work branch: `feat/global-surface-system`.
- Current configuration: `surface.mode="glass"`, `surface.nativeBlur=true`, `surface.islandNativeBlur=true`, and `surface.islandNativeBlurScreen="DP-1"`. The user confirmed the live DP-1 result worked correctly and authorized leaving it enabled by default.
- The previous DP-1 pilot used dynamically rebuilt one-pixel `Region` scanlines and was rolled back because dashboard expansion/collapse felt slow/stuck and the shape did not track accurately enough.
- The visible Canvas/MultiEffect island mask and input mask remain authoritative.
- The right-control-center rounded native blur is independent and must remain intact.

## Non-goals
- Do not promote `IslandNativePrototype.qml`.
- Do not enable island native blur for all screens; preserve the exact DP-1 selector and fail-closed behavior.
- Do not claim visual native-blur success without the recorded live validation.
- Do not retry review of the accumulated branch target; review only small work-unit candidates if requested/available.

## Tasks
1. [x] Recover Engram context and inspect current implementation.
2. [x] Replace dynamic per-row scanline churn with a bounded no-churn opt-in island blur representation.
3. [x] Verify QML/config/documentation structurally without unsafe live-device diagnostics.
4. [x] Report evidence and the next live visual/performance validation step.
5. [x] Run one-screen live opt-in validation on `DP-1`.
6. [x] Replace the too-narrow interior rectangle with fixed static bands for closer shape coverage.
7. [x] Replace the non-homogeneous twenty-nine-band approximation with a fixed Region composition tied directly to BarSection's notch geometry.

## Acceptance criteria
- Default configuration enables island native blur only for the exact `DP-1` screen; missing, malformed, unplugged, or unmatched screen names fail closed.
- When disabled, no island blur geometry is generated or attached for the bar islands.
- Any retained opt-in path avoids per-row QML object creation/destruction during dashboard geometry animation.
- The opt-in representation is a fixed Region composition per island: a bottom-rounded central body, enabled square notch caps, cap-local subtractive ellipse cutouts, and bounded lower wrap-corner approximations matching the authoritative notch geometry. It is a bounded approximation and does not claim exact Canvas alpha-mask parity.
- RCC blur, visible masks, input masks, routing, focus, services, and multi-monitor behavior remain unchanged.
- Documentation records the tradeoff honestly: protocol regions cannot exactly reproduce antialiased Canvas masks.

## Evidence log
- Engram summary recovered: latest continuation summary records rollback commit `2820fba` and user decision to redesign/correct rather than re-enable the current scanline pilot.
- Exploration confirmed current branch `feat/global-surface-system` is ahead of origin by one commit; the shipped config now uses `islandNativeBlur=true` / `islandNativeBlurScreen="DP-1"`.
- The retained opt-in now uses a statically declared `Region` composition per island, with declarative geometry bindings and no generated slices or destroy/recreate loop. The composition adds bounded lower wrap-corner coverage alongside the body and caps; the visible Canvas mask and input mask remain authoritative.
- Static verification passed through `gentle-ai-verify`: Qt 6 `qmllint` for `IslandBlurRegion.qml` and `git diff --check` produced no diagnostics.
- Ricardo authorized a one-screen validation. The live test used `surface.islandNativeBlur=true` and `surface.islandNativeBlurScreen="DP-1"`; the user confirmed the result worked correctly and authorized these values as the shipped default.
- First live screenshot feedback confirmed fluency returned, but the single interior rectangle shape was too narrow.
- The follow-up opt-in path uses direct Region coordinates: a central body plus cap-local and lower-wrap ellipse cutouts, with no synthetic geometry and no per-row bands. The visible Canvas mask remains authoritative.
- Twenty-nine-band verification passed: JSON parse, Qt 6 `qmllint`, `git diff --check`, soft reload, and log check with no post-reload `ERROR`; screenshot captured at `/tmp/native-blur-twenty-nine-bands-DP-1.png`.
- User screenshot showed the twenty-nine-band shape still wrong; the likely issue was not just band count, but coordinate mapping through synthetic `Item` geometry inside `Region`. The replacement uses direct `Region` coordinates and cap-local subtraction, matching BarSection's section origin while retaining fixed no-churn objects.
- Work-unit commit recorded: `ee982ed` (`feat(quickshell): refine native island blur pilot`). DP-1 is now the intentional shipped default after live validation; lower edges, visible band homogeneity, and other edge tuning remain follow-up work.
