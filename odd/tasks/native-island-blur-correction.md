# Native island blur correction

## Goal
Improve the opt-in island blur shape after live screenshots showed fluency returned but the five-band approximation remained visibly coarse. Keep the active one-screen test bounded and avoid re-enabling the failed scanline pilot as a default.

## Context
- Work branch: `feat/global-surface-system`.
- Current committed configuration: `surface.mode="glass"`, `surface.nativeBlur=true`, `surface.islandNativeBlur=false`, and `surface.islandNativeBlurScreen=""`. The DP-1 validation was a live test only and must not remain enabled by default.
- The previous DP-1 pilot used dynamically rebuilt one-pixel `Region` scanlines and was rolled back because dashboard expansion/collapse felt slow/stuck and the shape did not track accurately enough.
- The visible Canvas/MultiEffect island mask and input mask remain authoritative.
- The right-control-center rounded native blur is independent and must remain intact.

## Non-goals
- Do not promote `IslandNativePrototype.qml`.
- Do not re-enable island native blur in `config.json` by default.
- Do not claim visual native-blur success without live evidence.
- Do not retry review of the accumulated branch target; review only small work-unit candidates if requested/available.

## Tasks
1. [x] Recover Engram context and inspect current implementation.
2. [x] Replace dynamic per-row scanline churn with a bounded no-churn opt-in island blur representation.
3. [x] Verify QML/config/documentation structurally without unsafe live-device diagnostics.
4. [x] Report evidence and the next live visual/performance validation step.
5. [x] Run one-screen live opt-in validation on `DP-1`.
6. [x] Replace the too-narrow interior rectangle with fixed static bands for closer shape coverage.
7. [x] Refine the five-band approximation to twenty-nine fixed bands tied to the shared radius geometry.

## Acceptance criteria
- Default configuration remains safe fallback: island native blur disabled and no screen selected.
- When disabled, no island blur geometry is generated or attached for the bar islands.
- Any retained opt-in path avoids per-row QML object creation/destruction during dashboard geometry animation.
- The opt-in representation is twenty-nine declarative static bands per island, with fourteen slices for each rounded end and one central slice, derived from shared quarter-circle helpers; it is a bounded approximation and does not claim exact Canvas alpha-mask parity or include decorative wraps.
- RCC blur, visible masks, input masks, routing, focus, services, and multi-monitor behavior remain unchanged.
- Documentation records the tradeoff honestly: protocol regions cannot exactly reproduce antialiased Canvas masks.

## Evidence log
- Engram summary recovered: latest continuation summary records rollback commit `2820fba` and user decision to redesign/correct rather than re-enable the current scanline pilot.
- Exploration confirmed current branch `feat/global-surface-system` is ahead of origin by one commit and working config keeps `islandNativeBlur=false` / `islandNativeBlurScreen=""`.
- The retained opt-in now uses five statically declared `Region` bands per island, with declarative geometry bindings and no generated slices or destroy/recreate loop. The bands add coarse corner coverage while intentionally omitting decorative wraps; the visible Canvas mask and input mask remain authoritative.
- Static verification passed through `gentle-ai-verify`: Qt 6 `qmllint` for `IslandBlurRegion.qml` and `git diff --check` produced no diagnostics.
- Ricardo authorized a one-screen opt-in validation. The live test temporarily used `surface.islandNativeBlur=true` and `surface.islandNativeBlurScreen="DP-1"`; native review required restoring the committed safe default.
- First live screenshot feedback confirmed fluency returned, but the single interior rectangle shape was too narrow.
- The opt-in path now uses twenty-nine fixed declarative bands derived from `IslandGeometry` instead of one narrow rectangle or dynamic scanlines. The finer bands retain a bounded approximation: decorative wraps remain excluded and the visible Canvas mask remains authoritative.
- Twenty-nine-band verification passed: JSON parse, Qt 6 `qmllint`, `git diff --check`, soft reload, and log check with no post-reload `ERROR`; screenshot captured at `/tmp/native-blur-twenty-nine-bands-DP-1.png`.
- User screenshot showed the twenty-nine-band shape still wrong; the likely issue was not just band count, but coordinate mapping through synthetic `Item` geometry inside `Region`. The bands now use direct `Region` `x`/`y`/`width`/`height` bindings, matching the historical scanline coordinate space while retaining fixed no-churn objects.
- Work-unit commit recorded: `ee982ed` (`feat(quickshell): refine native island blur pilot`). Follow-up correction restores the committed safe default; lower edges and visible band homogeneity remain future opt-in tuning work.
