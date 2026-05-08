import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"

RowLayout {
    id: root
    spacing: 4

    // Nombre del special workspace activo ("" si ninguno está visible)
    property string activeSpecial: ""

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
            // activespecial>>name,monitor — vacío cuando se cierra
            if (event.name === "activespecial") {
                const parts = event.data.split(",")
                root.activeSpecial = parts[0] ?? ""
            }
        }
    }

    Repeater {
        model: Hyprland.workspaces

        delegate: Item {
            id: wsItem

            required property var modelData

            readonly property bool isActive: {
                const name = modelData.name
                if (name === "special:magic" || name.startsWith("special:"))
                    return root.activeSpecial === name
                return modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
            }

            // true cuando este workspace normal está debajo de un special activo
            readonly property bool isUnderSpecial: {
                const name = modelData.name
                if (name.startsWith("special:")) return false
                return root.activeSpecial !== "" &&
                       modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
            }

            readonly property color activeColor: {
                const name = modelData.name
                if (name.startsWith("special:")) return Colors.cyan
                if (isUnderSpecial) return Colors.accent
                return Colors.accent
            }

            Layout.alignment: Qt.AlignVCenter

            implicitWidth: wsRow.implicitWidth + 16
            implicitHeight: 26

            // Cajita — activo: accent / inactivo: surface
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: wsItem.isActive
                    ? Qt.rgba(wsItem.activeColor.r, wsItem.activeColor.g, wsItem.activeColor.b, 0.15)
                    : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, 0.33)
                border {
                    width: 1
                    color: wsItem.isActive
                        ? Qt.rgba(wsItem.activeColor.r, wsItem.activeColor.g, wsItem.activeColor.b, 0.6)
                        : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.3)
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
                    color: wsItem.isActive ? wsItem.activeColor : Colors.muted
                    font {
                        family: "CaskaydiaMono Nerd Font"
                        pixelSize: 12
                        bold: wsItem.isActive
                    }
                }

                // Separador entre número y apps — solo si hay apps
                Text {
                    text: "•"
                    color: Colors.muted
                    font.pixelSize: 10
                    opacity: 0.8
                    visible: wsItem.modelData.toplevels.values.length > 0
                }

                // Apps del workspace — via workspace.toplevels (bindable, reactivo)
                Repeater {
                    model: wsItem.modelData.toplevels

                    delegate: RowLayout {
                        required property var modelData
                        required property int index

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
                            opacity: 0.8
                            visible: index > 0
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
