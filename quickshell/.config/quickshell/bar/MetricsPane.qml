import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property QtObject systemStatsState: null

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.dashboardCardGap

        MetricCard {
            icon: "󰻠"
            label: "CPU"
            value: root.systemStatsState?.cpu ?? 0
            history: root.systemStatsState?.cpuHistory ?? []
            color: Colors.orange
        }

        MetricCard {
            icon: "󰍛"
            label: "RAM"
            value: root.systemStatsState?.ram ?? 0
            history: root.systemStatsState?.ramHistory ?? []
            color: Colors.blue
        }

        MetricCard {
            icon: "󰢮"
            label: "GPU"
            value: root.systemStatsState?.gpu ?? 0
            history: root.systemStatsState?.gpuHistory ?? []
            color: Colors.magenta
            disabled: !(root.systemStatsState?.gpuAvailable ?? true)
        }

        Item { Layout.preferredHeight: Theme.spacingXs }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.dashboardFooterHeight
            spacing: Theme.spacingSm

            FooterStat {
                icon: "󰋊"
                label: "DSK"
                value: (root.systemStatsState?.disk ?? 0).toFixed(1) + " MB/s"
                color: Colors.brown
            }

            FooterStat {
                icon: "󰈀"
                label: "NET"
                value: (root.systemStatsState?.netUp ?? false) ? "UP" : "DOWN"
                color: (root.systemStatsState?.netUp ?? false) ? Colors.green : Colors.red
            }

            FooterStat {
                icon: "󰕾"
                label: "VOL"
                value: (root.systemStatsState?.muted ?? false) ? "MUTED" : (root.systemStatsState?.volume ?? 0) + "%"
                color: (root.systemStatsState?.muted ?? false) ? Colors.muted : Colors.yellow
            }
        }
    }

    component FooterStat: RowLayout {
        property string icon: ""
        property string label: ""
        property string value: ""
        property color color: Colors.textDim

        Layout.fillWidth: true
        spacing: Theme.spacingXs

        Text {
            text: parent.icon
            color: parent.color
            font { family: Colors.monoFont; pixelSize: Theme.fontSizeLabel }
        }

        Text {
            text: parent.label
            color: parent.color
            font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
        }

        Text {
            Layout.fillWidth: true
            text: parent.value
            color: Colors.textDim
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
        }
    }
}
