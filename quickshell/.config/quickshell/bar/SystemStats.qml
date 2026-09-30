import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Data engine only — instantiated once in shell.qml and injected into Bar via
// `systemStatsState` so per-monitor Bar instances never duplicate polling.
Item {
    id: root

    property alias dataState: state

    QtObject {
        id: state
        property real ram: 0
        property real gpu: 0
        property real cpu: 0
        property real disk: 0
        property bool netUp: false
        property string netInterface: ""
        property real netRx: 0
        property real netTx: 0
        property real prevNetRxBytes: 0
        property real prevNetTxBytes: 0
        property real prevNetTimestamp: 0
        property var netHistory: []
        property real prevDiskSectors: 0
        property int  volume: 0
        property bool muted: false
        property var cpuHistory: []
        property var ramHistory: []
        property var gpuHistory: []
        property bool gpuAvailable: true
        readonly property int maxHistorySamples: 32

        function updateHistory(arr, val) {
            const next = arr.slice()
            next.push(val)
            if (next.length > maxHistorySamples)
                next.shift()
            return next
        }
    }

    Process {
        id: poller
        command: [
            "bash", "-c", [
                "ram=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%.0f\", (t-a)/t*100}' /proc/meminfo);",
                "gpu=$(cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || echo NA);",
                "read_cpu() { awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat; };",
                "c1=$(read_cpu); sleep 0.2; c2=$(read_cpu);",
                "cpu=$(awk -v a=\"$c1\" -v b=\"$c2\" 'BEGIN{",
                "  split(a,x); split(b,y);",
                "  dt=y[1]-x[1]; di=y[2]-x[2];",
                "  printf \"%.0f\", (dt-di)/dt*100}');",
                "disk=$(awk '$3==\"nvme0n1\"{print ($6+$10)}' /proc/diskstats);",
                "iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}');",
                "net=0; rx=0; tx=0;",
                "if [ -n \"$iface\" ]; then",
                "  net=1;",
                "  vals=$(awk -v iface=\"$iface\" '$1 ~ iface\":\" {gsub(\":\", \"\", $1); print $2, $10}' /proc/net/dev);",
                "  rx=$(echo \"$vals\" | awk '{print $1+0}');",
                "  tx=$(echo \"$vals\" | awk '{print $2+0}');",
                "fi;",
                "echo \"$ram|$gpu|$cpu|$disk|$net|$iface|$rx|$tx\""
            ].join(" ")
        ]

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|")
                if (parts.length < 5) return

                state.ram = parseFloat(parts[0]) || 0
                state.cpu = parseFloat(parts[2]) || 0
                state.ramHistory = state.updateHistory(state.ramHistory, state.ram)
                state.cpuHistory = state.updateHistory(state.cpuHistory, state.cpu)

                if (parts[1] === "NA" || parts[1] === "") {
                    state.gpuAvailable = false
                    state.gpu = 0
                } else {
                    state.gpuAvailable = true
                    state.gpu = parseFloat(parts[1]) || 0
                    state.gpuHistory = state.updateHistory(state.gpuHistory, state.gpu)
                }

                // Disk: delta sectors * 512B / 1MiB / interval(2s) = MB/s
                const sectors = parseFloat(parts[3]) || 0
                if (state.prevDiskSectors > 0)
                    state.disk = Math.round((sectors - state.prevDiskSectors) * 512 / 1048576 / 2 * 10) / 10
                state.prevDiskSectors = sectors

                state.netUp = parseInt(parts[4]) > 0
                state.netInterface = parts.length > 5 ? parts[5] : ""

                const rxBytes = parts.length > 6 ? (parseFloat(parts[6]) || 0) : 0
                const txBytes = parts.length > 7 ? (parseFloat(parts[7]) || 0) : 0
                const now = Date.now()
                if (state.prevNetTimestamp > 0 && rxBytes >= state.prevNetRxBytes && txBytes >= state.prevNetTxBytes) {
                    const seconds = Math.max(0.1, (now - state.prevNetTimestamp) / 1000)
                    state.netRx = Math.round((rxBytes - state.prevNetRxBytes) / 1048576 / seconds * 10) / 10
                    state.netTx = Math.round((txBytes - state.prevNetTxBytes) / 1048576 / seconds * 10) / 10
                    state.netHistory = state.updateHistory(state.netHistory, Math.min(100, (state.netRx + state.netTx) * 10))
                } else {
                    state.netRx = 0
                    state.netTx = 0
                }
                state.prevNetRxBytes = rxBytes
                state.prevNetTxBytes = txBytes
                state.prevNetTimestamp = now

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
