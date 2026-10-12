# Wi-Fi and Bluetooth action feedback

## Goal
Make asynchronous Wi-Fi and Bluetooth actions visibly communicate progress, success, and failure without changing service commands, routing, focus, or multi-monitor behavior.

## Scope
- Wi-Fi: make scanning visibly and consistently indicate in-progress state, disable duplicate scan requests, and surface scan failure without stale success state.
- Bluetooth: show pairing/connecting/disconnecting progress on the selected device, prevent duplicate actions, and provide retryable failure feedback.
- Preserve existing quiet visual grammar, inline disclosure behavior, and service abstractions.

## Tasks
1. [x] Map action lifecycle and define state ownership.
2. [x] Implement Wi-Fi scan/loading feedback.
3. [x] Implement Bluetooth action progress/retry feedback.
4. [ ] Verify behavior, document evidence, and run native review.

## Implementation evidence

- `WifiService.qml` now keeps scan state through the post-scan refresh and retains a recoverable result/error state.
- `BluetoothService.qml` now exposes address-bound action kind/status/error and confirms successful actions against a fresh device snapshot.
- `WifiControlCard.qml` and `BluetoothControlCard.qml` render compact loading/error/retry feedback without changing the service commands or overlay architecture.
- Implementation commit on `feat/global-surface-system`: `44083a5` (`feat(quickshell): add network action feedback`).
- Static/reload verification passed: JSON parse, focused Qt6 `qmllint` exit 0, `git diff --check`, soft reload, and `Configuration Loaded` with no subsequent `ERROR`. Interactive service actions remain unverified by design.

## Non-goals
- No backend migration from CLI services.
- No changes to overlay routing, focus, Escape, multi-monitor policy, or panel geometry.
- No live service mutations during automated verification.

## Acceptance criteria
- Wi-Fi scan action has an obvious, bounded in-progress state and cannot be queued repeatedly.
- Wi-Fi scan success/failure leaves the UI truthful and recoverable.
- Bluetooth pair/connect/disconnect actions show device-specific progress and prevent duplicate requests.
- Bluetooth failures remain visible with a retry path that invokes the existing service action.
- Existing connected/paired/available grouping and disclosure behavior remain intact.
- Qt6 lint, reload, and focused structural checks pass.
