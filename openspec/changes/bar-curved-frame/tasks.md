# Tasks: Bar Curved Frame — Composed Segments

> Historical phases 1–14 (ShapePath approach) are [x] completed and checkpointed at `5b85301`. This revision adopts the **Composed Rectangle Segments** approach per design revision. Tasks below are the authoritative plan for the next apply.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~80–120 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Theme/Config Foundation

- [x] 1.1 `Theme.qml`: Add `barNotchGapWidth: 30` + `barNotchDepthRatio: 0.2` properties
- [x] 1.2 `Theme.qml`: Wire both in `applyConfig()`; accept old `bar.curveDepthRatio` as fallback for `notchDepthRatio`
- [x] 1.3 `config.json`: Add `bar.notchGapWidth: 30`; replace `curveDepthRatio` with `notchDepthRatio: 0.2`

## Phase 2: Bar.qml — Composed Rectangle Silhouette

- [x] 2.1 `Bar.qml`: Remove entire Shape + ShapePath block + `import QtQuick.Shapes`
- [x] 2.2 `Bar.qml`: Add `topConnector` Rectangle — anchors.left/right/top, height=`connectorHeight`, z:1, same fill as segments
- [x] 2.3 `Bar.qml`: Add `leftSegment` Rectangle — width=`centerTab.x - gapHalf`, bottomLeft/RightRadius=`tabRadius`, z:0
- [x] 2.4 `Bar.qml`: Add `centerSegment` Rectangle — x=`centerTab.x + gapHalf`, width=`centerTab.width - barNotchGapWidth`, bottom radii, z:0
- [x] 2.5 `Bar.qml`: Add `rightSegment` Rectangle — x=`centerTab.x + centerTab.width + gapHalf`, width=`parent.width - x`, bottom radii, z:0
- [x] 2.6 `Bar.qml`: Wire `visible: barStyle === "silhouette"` on all 4 rects; fully hidden on `"plain"`
- [x] 2.7 `Bar.qml`: Add computed block: `notchDepth`, `connectorHeight`, `gapHalf` as `readonly property real`

## Phase 3: Debug Mode

- [x] 3.1 `Bar.qml`: When `debugBarSilhouette` — fill segments with `Qt.rgba(1.0, 0.2, 0.2, 0.65)` + `border.color: "#ff3344"`, `border.width: 1`
- [x] 3.2 `Bar.qml`: Normal mode — fill with `Qt.rgba(Colors.base01.r, ..., Theme.tabBgOpacity)`; no Rectangle border
- [x] 3.3 Theme/Config: Ensure `debug.barSilhouette` preserved in Theme.qml applyConfig() + config.json

## Phase 4: Verification

- [x] 4.1 Run `qmllint` on Bar.qml (exit 0) + Theme.qml (exit 255 — pre-existing Quickshell singleton bug, not caused by changes)
- [~] 4.2 CP1 (default): Restart — 3 full-height island segments with transparent gaps, breathing islands visual (partial — verified in progress)
- [~] 4.3 CP2 (MPRIS active): Same island height, no layout shift (partial — pending active MPRIS test)
- [~] 4.4 CP3 (dropdown): Bar unchanged, overlay above app (partial — pending runtime)
- [~] 4.5 CP4 (plain mode): `bar.style: "plain"` — no background rects visible (partial — pending runtime)
- [~] 4.6 Debug on/off: Toggle `debug.barSilhouette` — high-contrast red on actual islands; toggle via config hot-reload + restart (partial — code verified, pending runtime)
- [~] 4.7 Runtime: IPC coordinates + all overlay interactions still functional (partial — pending runtime)

## Phase 5: Island Tuning (Transparent Gaps) [completed in a1c9fa7]

- [x] 5.1 `Bar.qml`: Remove `topConnector` — full-width connector removed; gaps now extend full height
- [x] 5.2 `Bar.qml`: Make segments full-height (`y:0`, `height:parent.height`) — each island spans bar height
- [x] 5.3 `Bar.qml`: Add `topLeftRadius`/`topRightRadius` to all islands — outer edges square, gap edges rounded
- [x] 5.4 `Bar.qml`: Remove unused `notchDepth`/`connectorHeight` computed properties
- [x] 5.5 `Bar.qml`: Remove topConnector Rectangle block (~8 lines)
- [x] 5.6 Verify: qmllint exit 0 on Bar.qml after changes
- [x] 5.7 Runtime: Restart Quickshell — inspect breathing islands with transparent gaps

## Phase 6: Final Polish & Archive

- [ ] 6.1 Visual tuning of island appearance (gaps, radii, colors) — requires Quickshell runtime iteration
- [ ] 6.2 Set `debug.barSilhouette: false` in config.json before final/archive
- [ ] 6.3 Reconcile all runtime CPs (4.2–4.7) — confirm via Quickshell restart
- [ ] 6.4 Run final verify — expect PASS (no warnings)
- [ ] 6.5 Archive change — run sdd-archive to sync delta specs to main and clean up
