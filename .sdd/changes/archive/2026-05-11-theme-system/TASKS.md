# Tasks: Theme System

> **ARCHIVED** — Completed and verified on 2026-05-11. All 10/10 tasks complete.
> Synced to: `specs/theme-system.md` | Index updated: `SPECS.md`

---

## Phase 1: Foundation

- [x] 1.1 Create base `quickshell/.config/quickshell/theme/Theme.qml` with mutable default tokens only: `radiusSm/Md/Lg/Pill`, `spacingXs/Sm/Md/Lg/Xl`, `opacitySurface/Overlay/Border/Dim`, `barHeight`, `animFast/Normal/Slow`, `fontSizeCaption/Label/Body/BodyLg/Icon`; Acceptance: imports cleanly, matches current visuals, no `FileView`/debounce yet, no crash.
- [x] 1.2 Register singleton in `quickshell/.config/quickshell/theme/qmldir` as `Theme 1.0 Theme.qml`; Acceptance: `import "../theme"` resolves `Theme` everywhere, no `Type Theme unavailable` error.

## Phase 2: Low-risk component migration

- [x] 2.1 Migrate `quickshell/.config/quickshell/bar/SystemStats.qml` to `Theme.radiusSm`, `Theme.opacityOverlay`, `Theme.opacityBorder`, `Theme.fontSizeLabel`, `Theme.fontSizeBody`; Acceptance: stat pills/time chip look identical and shell stays stable.
- [x] 2.2 Migrate `quickshell/.config/quickshell/bar/Workspaces.qml` to `Theme.radiusSm`, `Theme.opacityDim`, `Theme.opacityOverlay`, `Theme.opacityBorder`; Acceptance: active/special workspace styling is visually unchanged, no binding errors.
- [x] 2.3 Migrate `quickshell/.config/quickshell/bar/MprisIndicator.qml` to `Theme.radiusSm`, `Theme.opacityOverlay`, `Theme.opacityBorder`, `Theme.animFast`; Acceptance: chip width animation and styling stay identical, no popup toggle regressions.

## Phase 3: Overlay and panel migration

- [x] 3.1 Migrate `quickshell/.config/quickshell/bar/MprisPopup.qml` to `Theme.radiusSm/Md`, `Theme.opacitySurface`, `Theme.opacityBorder`, `Theme.spacingMd/Lg/Xl`, `Theme.animSlow`; Acceptance: popup placement/content spacing/progress animation match before, no crash with/without cover art.
- [x] 3.2 Migrate `quickshell/.config/quickshell/bar/PowerMenu.qml` and `bar/PowerMenuItem.qml` to `Theme.radiusSm/Md`, `Theme.opacitySurface`, `Theme.opacityBorder`, `Theme.opacityDim`, `Theme.spacingSm/Md`; Acceptance: trigger/menu rows/divider look identical, hover/keyboard navigation still work, no crash.
- [x] 3.3 Migrate `quickshell/.config/quickshell/launcher/LauncherCentered.qml` to `Theme.radiusSm/Lg`, `Theme.opacitySurface`, `Theme.opacityBorder`, `Theme.opacityDim`, `Theme.spacingSm/Md/Lg`, `Theme.fontSizeCaption/Label/Body`; Acceptance: launcher overlay/search/list/hint spacing stays identical, open/close/search still work.
- [x] 3.4 Migrate `quickshell/.config/quickshell/notifications/NotificationToast.qml` to `Theme.radiusSm/Md`, `Theme.opacitySurface`, `Theme.opacityBorder`, `Theme.spacingXs/Sm/Md`, `Theme.fontSizeCaption/Label/Body`, `Theme.animNormal`; Acceptance: toast card/actions/progress/appear animation look the same and dismiss paths do not crash.

## Phase 4: Critical coupling and hot reload

- [x] 4.1 Migrate bar height last in `quickshell/.config/quickshell/bar/Bar.qml`, `quickshell/.config/quickshell/notifications/Notifications.qml`, and `quickshell/.config/quickshell/bar/PowerMenu.qml` to `Theme.barHeight` plus existing spacing tokens; Acceptance: bar, notification offset, and powermenu anchor remain aligned exactly at 37px defaults, no layout break.
- [x] 4.2 Extend `quickshell/.config/quickshell/theme/Theme.qml` with `FileView`, 100ms `Timer` debounce, and `applyConfig()` partial overrides for all token groups; Acceptance: missing file uses defaults, invalid JSON fails silently, valid edits hot-reload within ~200ms, no crash.
- [x] 4.3 Create example `~/.config/quickshell/config.json` with every default token value (commented only if parser is upgraded from `JSON.parse` to JSONC; otherwise keep valid JSON); Acceptance: file documents all defaults, Quickshell loads it successfully, editing a value updates the bound UI live.
