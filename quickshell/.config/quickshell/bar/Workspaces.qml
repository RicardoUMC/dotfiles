import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"

GridLayout {
    id: root
    property bool vertical: false
    property string workspaceMode: "numbers"
    property string appMode: "active-icon"

    columns: root.vertical ? 1 : -1
    rows: root.vertical ? -1 : 1
    rowSpacing: Theme.spacingXs
    columnSpacing: Theme.spacingXs

    function desktopEntryForToplevel(toplevel) {
        const raw = toplevel && toplevel.lastIpcObject
            ? (toplevel.lastIpcObject["class"] ?? "") : ""
        const apps = DesktopEntries.applications.values
        if (apps) {
            for (let i = 0; i < apps.length; i++) {
                const entry = apps[i]
                if (entry?.id?.toLowerCase() === raw.toLowerCase()) return entry
            }
        }
        return null
    }

    function appLabelForToplevel(toplevel) {
        const entry = root.desktopEntryForToplevel(toplevel)
        if (entry && entry.name) return entry.name
        const raw = toplevel && toplevel.lastIpcObject
            ? (toplevel.lastIpcObject["class"] ?? "") : ""
        const name = raw.includes(".")
            ? raw.split(".").pop()
            : raw.replace(/-browser$/, "").replace(/-desktop$/, "")
        return name ? name.charAt(0).toUpperCase() + name.slice(1) : "Application"
    }

    function appIconForToplevel(toplevel) {
        const entry = root.desktopEntryForToplevel(toplevel)
        return entry && entry.icon
            ? Quickshell.iconPath(entry.icon, "application-x-executable")
            : ""
    }

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

            // `activated` is session-global. Restrict active-app selection to
            // this monitor's active workspace, then fall back to the newest
            // toplevel when compositor activation is unavailable.
            readonly property var displayedToplevels: {
                const values = wsItem.modelData.toplevels.values || []
                if (root.appMode === "hidden") return []
                if (root.appMode === "all-icons" || root.appMode === "vertical-labels")
                    return values
                if (!wsItem.isActive || values.length === 0) return []
                const active = []
                for (let i = 0; i < values.length; i++) {
                    if (values[i].activated) active.push(values[i])
                }
                return active.length > 0 ? [active[0]] : [values[values.length - 1]]
            }

            visible: root.workspaceMode !== "active-only" || wsItem.isActive
            Layout.alignment: Qt.AlignVCenter
            readonly property color activeColor:
                wsItem.isSpecial ? Colors.cyan : Colors.accent

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
                        if (root.workspaceMode === "bullets") return "•"
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
                    visible: root.appMode === "vertical-labels" && wsItem.displayedToplevels.length > 0
                }

                Repeater {
                    model: wsItem.displayedToplevels

                    delegate: Item {
                        required property var modelData
                        required property int index
                        implicitWidth: root.appMode === "vertical-labels" && root.vertical
                            ? Theme.fontSizeLabel : Theme.fontSizeIcon
                        implicitHeight: root.appMode === "vertical-labels" && root.vertical
                            ? Math.max(Theme.barChipHeight, Theme.fontSizeLabel * 4)
                            : Theme.fontSizeIcon

                        Image {
                            anchors.centerIn: parent
                            width: Theme.fontSizeIcon
                            height: Theme.fontSizeIcon
                            source: root.appIconForToplevel(parent.modelData)
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            visible: root.appMode === "active-icon" || root.appMode === "all-icons"
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.appLabelForToplevel(parent.modelData)
                            color: wsItem.isActive ? Colors.textDim : Colors.muted
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                            rotation: root.vertical ? -90 : 0
                            visible: root.appMode === "vertical-labels"
                        }
                    }
                }
            }
        }
    }
}
