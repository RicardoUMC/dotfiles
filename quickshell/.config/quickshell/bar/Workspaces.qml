import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"

RowLayout {
    id: root
    spacing: 4

    property string activeSpecial: ""

    // Initial refresh — Hyprland may not report toplevels immediately on startup
    Timer {
        interval: 2000
        running: true
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow")
                Hyprland.refreshToplevels()

            if (event.name === "activespecial")
                root.activeSpecial = event.data.split(",")[0] ?? ""
        }
    }

    Repeater {
        model: Hyprland.workspaces

        delegate: Item {
            id: wsItem
            required property var modelData

            readonly property bool isActive: {
                const name = modelData.name
                if (name.startsWith("special:")) return root.activeSpecial === name
                return modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
            }

            // True when this normal workspace is visible but overlaid by an active special
            readonly property bool isUnderSpecial: {
                if (modelData.name.startsWith("special:")) return false
                return root.activeSpecial !== "" &&
                       modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
            }

            readonly property color activeColor:
                modelData.name.startsWith("special:") ? Colors.cyan : Colors.accent

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: wsRow.implicitWidth + 16
            implicitHeight: 26

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

                Text {
                    text: {
                        const name = modelData.name
                        if (name === "special:magic") return "󰓪"
                        if (name.startsWith("special:")) return "󰎔"
                        return name
                    }
                    color: wsItem.isActive ? wsItem.activeColor : Colors.muted
                    font {
                        family: Colors.monoFont
                        pixelSize: 12
                        bold: wsItem.isActive
                    }
                }

                Text {
                    text: "•"
                    color: Colors.muted
                    font.pixelSize: 10
                    opacity: 0.8
                    visible: wsItem.modelData.toplevels.values.length > 0
                }

                Repeater {
                    model: wsItem.modelData.toplevels

                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        spacing: 4

                        readonly property string appName: {
                            const raw = modelData.lastIpcObject["class"] ?? ""
                            // Prefer the desktop entry name (same source as the launcher)
                            const apps = DesktopEntries.applications.values
                            if (apps) {
                                for (let i = 0; i < apps.length; i++) {
                                    const e = apps[i]
                                    if (e?.id?.toLowerCase() === raw.toLowerCase())
                                        return e.name
                                }
                            }
                            // Fallback: reverse-DNS → last segment; plain name → strip suffixes
                            const name = raw.includes(".")
                                ? raw.split(".").pop()
                                : raw.replace(/-browser$/, "").replace(/-desktop$/, "")
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
                            font { family: Colors.monoFont; pixelSize: 11 }
                        }
                    }
                }
            }
        }
    }
}
