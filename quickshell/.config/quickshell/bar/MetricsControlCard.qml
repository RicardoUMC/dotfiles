import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + Theme.spacingSm * 2
    radius: Theme.radiusLg
    color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, 0.12)
    border.width: 0

    property var systemStatsState: null
    property bool expanded: false

    function statValue(name, fallback) {
        if (root.systemStatsState && root.systemStatsState[name] !== undefined && root.systemStatsState[name] !== null)
            return root.systemStatsState[name]
        return fallback
    }

    function percentText(value) {
        return Math.round(Math.max(0, Math.min(100, Number(value || 0)))) + "%"
    }

    function historyValue(name) {
        if (root.systemStatsState && root.systemStatsState[name])
            return root.systemStatsState[name]
        return []
    }

    function throughputText(value) {
        const mb = Number(value || 0)
        if (mb >= 10)
            return Math.round(mb) + " MB/s"
        if (mb >= 0.1)
            return mb.toFixed(1) + " MB/s"
        return Math.round(mb * 1024) + " KB/s"
    }

    function networkSummary() {
        const netUp = !!statValue("netUp", false)
        const rx = Number(statValue("netRx", 0) || 0)
        const tx = Number(statValue("netTx", 0) || 0)
        if (rx > 0 || tx > 0)
            return "↓" + throughputText(rx) + " ↑" + throughputText(tx)
        return netUp ? "NET online" : "NET offline"
    }

    onVisibleChanged: if (!visible) expanded = false

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 2
        radius: Theme.radiusPill
        color: Colors.accent
        opacity: root.expanded ? 0.80 : 0.45
    }

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingSm
        spacing: Theme.spacingSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Text {
                text: "󰓅"
                color: root.expanded ? Colors.accent : Colors.textDim
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
            }

            Text {
                Layout.fillWidth: true
                text: "Metrics"
                color: Colors.text
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeBodyLg }
            }

            Text {
                text: root.expanded ? "⌃" : "⌄"
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeBodyLg }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            CompactMetric {
                Layout.fillWidth: true
                label: "CPU"
                value: root.percentText(root.statValue("cpu", 0))
                history: root.historyValue("cpuHistory")
                accentColor: Colors.orange
            }

            CompactMetric {
                Layout.fillWidth: true
                label: "RAM"
                value: root.percentText(root.statValue("ram", 0))
                history: root.historyValue("ramHistory")
                accentColor: Colors.blue
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: Theme.radiusMd
                color: Qt.rgba(Colors.base02.r, Colors.base02.g, Colors.base02.b, 0.16)
                border.width: 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXs
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "NET"
                        color: Colors.textDim
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.networkSummary()
                        elide: Text.ElideRight
                        color: root.statValue("netUp", false) ? Colors.green : Colors.red
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.expanded
            spacing: Theme.spacingSm

            QuietMetricRow {
                visible: root.statValue("gpuAvailable", true)
                icon: "󰢮"
                label: "GPU"
                value: root.percentText(root.statValue("gpu", 0))
                accentColor: Colors.magenta
            }

            QuietMetricRow {
                icon: "󰋊"
                label: "Disk I/O"
                value: Number(root.statValue("disk", 0) || 0).toFixed(1) + " MB/s"
                accentColor: Colors.brown
            }

            QuietMetricRow {
                icon: "󰈀"
                label: "Network"
                value: root.networkSummary()
                accentColor: root.statValue("netUp", false) ? Colors.green : Colors.red
            }

            Text {
                Layout.fillWidth: true
                text: "Telemetry is summarized here; primary device controls stay above."
                wrapMode: Text.WordWrap
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }

    component CompactMetric: Rectangle {
        id: metric

        property string label: ""
        property string value: ""
        property var history: []
        property color accentColor: Colors.accent

        implicitHeight: 42
        radius: Theme.radiusMd
        color: Qt.rgba(Colors.base02.r, Colors.base02.g, Colors.base02.b, 0.16)
        border.width: 0

        onHistoryChanged: spark.requestPaint()
        onAccentColorChanged: spark.requestPaint()

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingXs
            spacing: Theme.spacingXs

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: metric.label
                    color: Colors.textDim
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                }

                Text {
                    Layout.fillWidth: true
                    text: metric.value
                    color: metric.accentColor
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                }
            }

            Canvas {
                id: spark
                Layout.preferredWidth: 44
                Layout.preferredHeight: 24
                antialiasing: true

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    if (!metric.history || metric.history.length < 2)
                        return

                    const count = metric.history.length
                    const xStep = width / Math.max(1, count - 1)
                    ctx.beginPath()

                    for (let i = 0; i < count; i++) {
                        const sample = Math.max(0, Math.min(100, Number(metric.history[i] || 0)))
                        const x = i * xStep
                        const y = height - (sample / 100) * height
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }

                    ctx.strokeStyle = metric.accentColor
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }
        }
    }

    component QuietMetricRow: Rectangle {
        id: metricRow

        property string icon: ""
        property string label: ""
        property string value: ""
        property color accentColor: Colors.accent

        Layout.fillWidth: true
        implicitHeight: 34
        radius: Theme.radiusMd
        color: Qt.rgba(Colors.base02.r, Colors.base02.g, Colors.base02.b, 0.12)
        border.width: 0

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingXs
            spacing: Theme.spacingSm

            Text {
                text: metricRow.icon
                color: metricRow.accentColor
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
            }

            Text {
                Layout.fillWidth: true
                text: metricRow.label
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }

            Text {
                text: metricRow.value
                color: Colors.text
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }
        }
    }
}
