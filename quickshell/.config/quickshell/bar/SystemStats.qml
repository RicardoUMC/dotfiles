import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

RowLayout {
    id: root
    spacing: Theme.spacingMd

    property alias dataState: state

    QtObject {
        id: state
        property real ram: 0
        property real gpu: 0
        property real cpu: 0
        property real disk: 0
        property bool netUp: false
        property real prevDiskSectors: 0
        property int  volume: 0
        property bool muted: false
    }

    Process {
        id: poller
        command: [
            "bash", "-c", [
                "ram=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%.0f\", (t-a)/t*100}' /proc/meminfo);",
                "gpu=$(cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || echo 0);",
                "read_cpu() { awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat; };",
                "c1=$(read_cpu); sleep 0.2; c2=$(read_cpu);",
                "cpu=$(awk -v a=\"$c1\" -v b=\"$c2\" 'BEGIN{",
                "  split(a,x); split(b,y);",
                "  dt=y[1]-x[1]; di=y[2]-x[2];",
                "  printf \"%.0f\", (dt-di)/dt*100}');",
                "disk=$(awk '$3==\"nvme0n1\"{print ($6+$10)}' /proc/diskstats);",
                "net=$(ip route | grep -c '^default' || echo 0);",
                "echo \"$ram|$gpu|$cpu|$disk|$net\""
            ].join(" ")
        ]

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|")
                if (parts.length < 5) return

                state.ram = parseFloat(parts[0]) || 0
                state.gpu = parseFloat(parts[1]) || 0
                state.cpu = parseFloat(parts[2]) || 0

                // Disk: delta sectors * 512B / 1MiB / interval(2s) = MB/s
                const sectors = parseFloat(parts[3]) || 0
                if (state.prevDiskSectors > 0)
                    state.disk = Math.round((sectors - state.prevDiskSectors) * 512 / 1048576 / 2 * 10) / 10
                state.prevDiskSectors = sectors

                state.netUp = parseInt(parts[4]) > 0

                poller.running = false
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poller.running = true
    }

    Process {
        id: volPoller
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const m = data.trim().match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (!m) return
                state.volume = Math.round(parseFloat(m[1]) * 100)
                state.muted  = !!m[2]
                volPoller.running = false
            }
        }
    }

    Timer {
        interval: 200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: volPoller.running = true
    }

    function statColor(val) {
        if (val >= 80) return Colors.red
        if (val >= 60) return Colors.yellow
        return Colors.textDim
    }

}
