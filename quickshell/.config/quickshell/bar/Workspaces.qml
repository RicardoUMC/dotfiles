import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"

RowLayout {
    id: root
    spacing: 4

    // Hyprland monitor this island belongs to, injected by Bar. Null during
    // startup or a hot-plug until Quickshell registers the output, in which
    // case the island renders no chips at all instead of throwing and taking
    // the whole bar instance down with it.
    property var monitor: null
    // Injected from shell.qml through Bar: the single compositor-event owner
    // bumps this counter when a workspace moves between monitors. That
    // mutation notifies nothing on Hyprland.workspaces, so the filter below
    // needs this external invalidation to avoid going stale.
    property int workspaceMonitorTick: 0

    property string activeSpecial: ""
    property string activeSpecialMonitor: ""

    // Toplevel-refresh orchestration lives once in shell.qml. This component
    // only tracks shared compositor events it needs for rendering.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activespecial") return
            // Payload is "<specialName>,<monitorName>". An empty name means the
            // special workspace just closed on that monitor.
            const parts = event.data.split(",")
            root.activeSpecial = parts.length > 0 ? parts[0] : ""
            root.activeSpecialMonitor = parts.length > 1 ? parts[1] : ""
        }
    }

    readonly property string monitorName: root.monitor ? root.monitor.name : ""

    // Active workspace name of THIS monitor, never of the focused one: acting on
    // a background monitor must light that monitor's chip, not whichever monitor
    // holds focus. Workspace names are unique session-wide, so an empty string
    // is a safe "nothing active / monitor not resolved yet" sentinel — unlike an
    // id, which can legitimately be negative for named workspaces.
    readonly property string activeWorkspaceName: {
        const mon = root.monitor
        if (!mon || !mon.activeWorkspace) return ""
        return mon.activeWorkspace.name
    }

    // Special workspace name shown on this monitor, or "" when none is. Both
    // outputs can name their special the same way ("special:magic"), so the
    // owning monitor from the event payload is part of the match.
    readonly property string activeSpecialHere: root.monitor
        && root.activeSpecialMonitor === root.monitorName
        ? root.activeSpecial
        : ""

    // Hyprland.workspaces is a global model; this is the per-monitor view.
    // Identity is matched by monitor name, never by index or ordering. The view
    // rebuilds when workspaces are inserted or removed, when this instance's
    // monitor resolves or is replaced, and when the shell-level tick reports a
    // workspace moving between monitors — the mutation the model itself never
    // announces, which is what the bare tick read above exists for.
    readonly property var monitorWorkspaces: {
        root.workspaceMonitorTick
        const mon = root.monitor
        if (!mon) return []
        const monitorName = mon.name
        const all = Hyprland.workspaces.values
        const visible = []
        for (let i = 0; i < all.length; i++) {
            const ws = all[i]
            if (!ws.monitor) continue
            if (ws.monitor.name === monitorName) visible.push(ws)
        }
        return visible
    }

    Repeater {
        model: root.monitorWorkspaces

        delegate: Item {
            id: wsItem
            required property var modelData

            // Two qualified hops into the island scope so the display rules
            // below read local state only.
            readonly property string activeWorkspaceName: root.activeWorkspaceName
            readonly property string activeSpecialHere: root.activeSpecialHere

            readonly property string wsName: modelData.name
            readonly property bool isSpecial: wsName.startsWith("special:")

            readonly property bool isActive: wsItem.isSpecial
                ? wsItem.activeSpecialHere === wsItem.wsName
                : wsItem.wsName === wsItem.activeWorkspaceName

            // True when this normal workspace is visible but overlaid by an active special
            readonly property bool isUnderSpecial:
                !wsItem.isSpecial && wsItem.activeSpecialHere !== "" &&
                wsItem.wsName === wsItem.activeWorkspaceName

            readonly property color activeColor:
                wsItem.isSpecial ? Colors.cyan : Colors.accent

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: wsRow.implicitWidth + 16
            implicitHeight: Theme.barChipHeight

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: wsItem.isActive
                    ? Qt.rgba(wsItem.activeColor.r, wsItem.activeColor.g, wsItem.activeColor.b, Theme.opacityDim)
                    : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacityOverlay)
                border {
                    width: 1
                    color: wsItem.isActive
                        ? Qt.rgba(wsItem.activeColor.r, wsItem.activeColor.g, wsItem.activeColor.b, 0.6)
                        : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
                }
            }

            // Debug visual bounds overlay — per-pill (development scaffolding)
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: Theme.radiusSm
                border {
                    width: Theme.debugBorderWidth
                    color: Theme.debugBorderColor
                }
                visible: Theme.debugVisualBounds
                z: 999
            }

            RowLayout {
                id: wsRow
                anchors.centerIn: parent
                spacing: Theme.spacingXs

                Text {
                    text: {
                        const name = wsItem.wsName
                        if (name === "special:magic") return "󰓪"
                        if (name.startsWith("special:")) return "󰎔"
                        return name
                    }
                    color: wsItem.isActive ? wsItem.activeColor : Colors.muted
                    font {
                        family: Colors.monoFont
                        pixelSize: Theme.fontSizeLabel + 1
                        bold: wsItem.isActive
                    }
                }

                Text {
                    text: "•"
                    color: Colors.muted
                    font.pixelSize: Theme.fontSizeCaption
                    opacity: 0.8
                    visible: wsItem.modelData.toplevels.values.length > 0
                }

                Repeater {
                    model: wsItem.modelData.toplevels

                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        spacing: Theme.spacingXs

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
                            font.pixelSize: Theme.fontSizeCaption
                            opacity: 0.8
                            visible: index > 0
                        }

                        Text {
                            text: parent.appName
                            color: wsItem.isActive ? Colors.textDim : Colors.muted
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                        }
                    }
                }
            }
        }
    }
}
