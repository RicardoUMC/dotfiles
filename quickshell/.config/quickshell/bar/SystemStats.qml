import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

RowLayout {
    id: root
    spacing: 12

    // ── Estado interno ──────────────────────────────────────────
    QtObject {
        id: state

        property real ram: 0       // %
        property real gpu: 0       // %
        property real cpu: 0       // %
        property real disk: 0      // MB/s (read+write combinado)
        property bool netUp: false // tiene gateway activo
        property int  volume: 0    // 0-100
        property bool muted: false

        // Para calcular CPU delta entre muestras
        property real prevIdle: 0
        property real prevTotal: 0

        // Para calcular Disk delta entre muestras
        property real prevDiskSectors: 0
    }

    // ── Proceso que lee todas las métricas de una vez ────────────
    Process {
        id: poller
        command: [
            "bash", "-c", [
                // RAM
                "ram=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%.0f\", (t-a)/t*100}' /proc/meminfo);",
                // GPU (AMD sysfs)
                "gpu=$(cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || echo 0);",
                // CPU — dos lecturas con delta de 0.2s
                "read_cpu() { awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat; };",
                "c1=$(read_cpu); sleep 0.2; c2=$(read_cpu);",
                "cpu=$(awk -v a=\"$c1\" -v b=\"$c2\" 'BEGIN{",
                "  split(a,x); split(b,y);",
                "  dt=y[1]-x[1]; di=y[2]-x[2];",
                "  printf \"%.0f\", (dt-di)/dt*100}');",
                // Disco — sectores leídos+escritos en nvme0n1 (sector = 512 bytes)
                "disk=$(awk '$3==\"nvme0n1\"{print ($6+$10)}' /proc/diskstats);",
                // Red — tiene gateway?
                "net=$(ip route | grep -c '^default' || echo 0);",
                // Volumen
                "vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{",
                "  muted=($3==\"[MUTED]\") ? 1 : 0;",
                "  printf \"%d %d\", $2*100, muted}');",
                "echo \"$ram|$gpu|$cpu|$disk|$net|$vol\""
            ].join(" ")
        ]

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|")
                if (parts.length < 6) return

                state.ram = parseFloat(parts[0]) || 0
                state.gpu = parseFloat(parts[1]) || 0
                state.cpu = parseFloat(parts[2]) || 0

                // Disco: calculamos delta de sectores vs muestra anterior
                const sectors = parseFloat(parts[3]) || 0
                const prev = state.prevDiskSectors
                if (prev > 0) {
                    // sectores * 512 bytes / 1048576 = MB, entre el intervalo de 2s
                    state.disk = Math.round((sectors - prev) * 512 / 1048576 / 2 * 10) / 10
                }
                state.prevDiskSectors = sectors

                state.netUp = parseInt(parts[4]) > 0

                const volParts = parts[5].trim().split(" ")
                state.volume = parseInt(volParts[0]) || 0
                state.muted = volParts[1] === "1"

                poller.running = false
            }
        }
    }

    // Refresca cada 2 segundos
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poller.running = true
    }

    // ── Helpers ─────────────────────────────────────────────────
    function statColor(val) {
        if (val >= 80) return Colors.red
        if (val >= 60) return Colors.yellow
        return Colors.textDim
    }

    // ── Componente reutilizable: etiqueta + valor ────────────────
    component Stat: RowLayout {
        property string label: ""
        property string value: ""
        property color  labelColor: Colors.muted
        property color  valueColor: Colors.textDim
        spacing: 4

        Text {
            text: label
            color: parent.labelColor
            font { family: "CaskaydiaMono Nerd Font"; pixelSize: 10 }
        }
        Text {
            text: value
            color: parent.valueColor
            font { family: "CaskaydiaMono Nerd Font"; pixelSize: 11 }
        }
    }

    // ── RAM ──────────────────────────────────────────────────────
    Stat {
        label: "RAM"
        value: state.ram + "%"
        labelColor: Colors.blue
        valueColor: root.statColor(state.ram)
    }

    // ── GPU ──────────────────────────────────────────────────────
    Stat {
        label: "GPU"
        value: state.gpu + "%"
        labelColor: Colors.magenta
        valueColor: root.statColor(state.gpu)
    }

    // ── CPU ──────────────────────────────────────────────────────
    Stat {
        label: "CPU"
        value: state.cpu + "%"
        labelColor: Colors.orange
        valueColor: root.statColor(state.cpu)
    }

    // ── Disco ────────────────────────────────────────────────────
    Stat {
        label: "DSK"
        value: state.disk + " MB/s"
        labelColor: Colors.brown
        valueColor: Colors.textDim
    }

    // ── Red ──────────────────────────────────────────────────────
    Stat {
        label: "NET"
        value: state.netUp ? "ON" : "OFF"
        labelColor: Colors.green
        valueColor: state.netUp ? Colors.green : Colors.red
    }

    // ── Volumen ──────────────────────────────────────────────────
    Stat {
        label: "VOL"
        value: state.muted ? "MUTED" : state.volume + "%"
        labelColor: Colors.yellow
        valueColor: state.muted ? Colors.muted : Colors.textDim
    }

    // ── Separador ────────────────────────────────────────────────
    Text {
        text: "|"
        color: Colors.muted
        font.pixelSize: 10
        opacity: 0.3
    }

    // ── Reloj ────────────────────────────────────────────────────
    Text {
        id: timeText

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                const now = new Date()
                const days = ["Dom","Lun","Mar","Mié","Jue","Vie","Sáb"]
                const months = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]
                timeText.text = `${days[now.getDay()]} ${String(now.getDate()).padStart(2,"0")} ${months[now.getMonth()]}  ${String(now.getHours()).padStart(2,"0")}:${String(now.getMinutes()).padStart(2,"0")}`
            }
        }

        color: Colors.text
        font { family: "CaskaydiaMono Nerd Font"; pixelSize: 12 }
    }
}
