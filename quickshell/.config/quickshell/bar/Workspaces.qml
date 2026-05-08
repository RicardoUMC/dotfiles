import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"

RowLayout {
    id: root
    spacing: 4

    // Refresh al arranque (espera a que Hyprland reporte todo)
    Timer {
        interval: 2000
        running: true
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }

    // Refresh cada vez que abre o cierra una ventana
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow") {
                Hyprland.refreshToplevels()
            }
        }
    }

    Repeater {
        model: Hyprland.workspaces

        delegate: Item {
            id: wsItem

            required property var modelData

            readonly property bool isActive: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id

            Layout.alignment: Qt.AlignVCenter

            implicitWidth: wsRow.implicitWidth + 16
            implicitHeight: 26

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: wsItem.isActive
                    ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                    : "transparent"
                border {
                    width: wsItem.isActive ? 1 : 0
                    color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.5)
                }
            }

            RowLayout {
                id: wsRow
                anchors.centerIn: parent
                spacing: 4

                // Número del workspace
                Text {
                    text: {
                        const name = modelData.name
                        if (name === "special:magic") return "󰓪"
                        if (name.startsWith("special:")) return "󰎔"
                        return name
                    }
                    color: wsItem.isActive ? Colors.accent : Colors.muted
                    font {
                        family: "CaskaydiaMono Nerd Font"
                        pixelSize: 12
                        bold: wsItem.isActive
                    }
                }

                // Apps del workspace — via workspace.toplevels (bindable, reactivo)
                Repeater {
                    model: wsItem.modelData.toplevels

                    delegate: RowLayout {
                        required property var modelData

                        spacing: 4

                        readonly property string appName: {
                            const raw = modelData.lastIpcObject["class"] ?? ""
                            let name = raw
                                .replace(/^org\.\w+\./, "")
                                .replace(/-browser$/, "")
                                .replace(/-desktop$/, "")
                            return name.charAt(0).toUpperCase() + name.slice(1)
                        }

                        Text {
                            text: "|"
                            color: Colors.muted
                            font.pixelSize: 10
                            opacity: 0.5
                        }

                        Text {
                            text: parent.appName
                            color: wsItem.isActive ? Colors.textDim : Colors.muted
                            font {
                                family: "CaskaydiaMono Nerd Font"
                                pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }
}
