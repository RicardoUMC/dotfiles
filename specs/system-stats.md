# System Stats

**Status:** Implemented
**File:** `quickshell/.config/quickshell/bar/SystemStats.qml`

## Description
Right-aligned stats data provider for the bar metrics UI. `SystemStats.qml` exposes a `dataState` object used by both the compact `MetricsDropdown.qml` and the center dashboard Metrics pane.

## Metrics

| Label | Value | Source |
|-------|-------|--------|
| RAM | usage % | `/proc/meminfo` |
| GPU | busy % | `/sys/class/drm/card1/device/gpu_busy_percent` |
| CPU | usage % | `/proc/stat` |
| DSK | read+write MB/s | `/proc/diskstats` (nvme0n1) |
| NET | UP / DOWN | default route detection via `ip route` |
| VOL | volume % or MUTED | `wpctl get-volume` |

## Rolling history

- `dataState.cpuHistory`, `dataState.ramHistory`, and `dataState.gpuHistory` contain rolling percent samples for visual sparklines
- Histories are capped at 32 samples and are reassigned on update so QML bindings react reliably
- GPU history only updates when GPU data is available
- `dataState.gpuAvailable` is false when `/sys/class/drm/card1/device/gpu_busy_percent` returns the `NA` sentinel or no data; consumers must render unavailable GPU as `N/A`, not as a meaningful `0%`

## Color coding
- Label: contextual accent color per metric
- Value: dynamic based on load level (green → yellow → orange → red threshold)
- MUTED state: dimmed color

## Clock
- Format: `DDD DD MMM HH:MM` (e.g. `Dom 10 May  16:00`)
- Updates every second
- Font: `uiFont` (SF Pro Text)

## Polling intervals
- System stats: 1000ms
- Volume: 200ms (separate poller for responsiveness)
