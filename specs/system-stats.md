# System Stats

**Status:** Implemented
**File:** `quickshell/.config/quickshell/bar/SystemStats.qml`

## Description
Right-aligned stats bar showing system metrics and a clock.

## Metrics

| Label | Value | Source |
|-------|-------|--------|
| RAM | usage % | `/proc/meminfo` |
| GPU | busy % | `/sys/class/drm/card1/device/gpu_busy_percent` |
| CPU | usage % | `/proc/stat` |
| DSK | read+write MB/s | `/proc/diskstats` (nvme0n1) |
| NET | UP / OFF | `/sys/class/net/wlp11s0/operstate` |
| VOL | volume % or MUTED | `wpctl get-volume` |

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
