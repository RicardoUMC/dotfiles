import QtQuick
import QtQuick.Layouts
import "../services"
import "../theme"

// Wi-Fi specialty module.
//
// Layered composition:
//   Layer 1 — hero block for the connected network identity, with a
//             state-colored accent seam and a dedicated signal puck. The
//             hero's trailing edge carries the radio power switch, which
//             changes weight with the radio state:
//               on  — quiet borderless rail control, secondary to identity.
//               off — the hero itself becomes the action and the switch is
//                     emphasized so "turn it back on" is the one move left.
//   Layer 2 — quiet, dense "Nearby networks" group; Scan and the overflow
//             reveal live in its header, so the list body stays pure content.
//   Layer 3 — accent-tinted detail sheet for connect / password / forget.
//
// Geometry comes from Theme.qml, color and type from Colors.qml.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + Theme.spacingSm * 2
    radius: Theme.radiusLg
    color: Qt.rgba(Colors.backgroundAlt.r, Colors.backgroundAlt.g, Colors.backgroundAlt.b,
                   WifiService.wifiEnabled ? 0.30 : 0.18)
    border.width: 0

    property bool expanded: false
    property bool standalone: false
    property var selectedNetwork: null
    property string detailMode: "" // "known" | "password" | "open" | "forget"
    property string passwordText: ""
    // Radio power is requested through the service, which refreshes on its own
    // cadence; these track the outstanding request so the affordance never
    // reads as dead and never queues a second call while one is running.
    property bool powerPending: false
    property bool powerPendingTarget: false

    readonly property int visibleNetworkCount: 5
    // Overflow is a view mode, not a different list: the preview slice stays
    // the default and the group-header control reveals the rest in place.
    property bool showAllNetworks: false
    readonly property int hiddenNetworkCount: Math.max(0, sortedNetworks.length - visibleNetworkCount)
    readonly property bool networksTruncated: hiddenNetworkCount > 0

    // A radio toggle is not instant: `nmcli radio` answers, then the service
    // refresh has to observe it. Settle window is three refresh cycles, derived
    // from Theme.animSlow so it stays inside the shell's timing tokens.
    readonly property int powerSettleMs: Theme.animSlow * 30

    function requestPower(nextState) {
        if (powerPending)
            return
        powerPendingTarget = nextState
        powerPending = true
        clearSelection()
        WifiService.setWifiEnabled(nextState)
        powerSettleTimer.restart()
    }
    readonly property bool connected: WifiService.activeSsid.length > 0
    readonly property var sortedNetworks: sortedNetworkList()
    readonly property var visibleNetworks: showAllNetworks
                                           ? sortedNetworks
                                           : sortedNetworks.slice(0, visibleNetworkCount)

    // Single source of truth for "state color": seam, status label and puck.
    readonly property color heroStateColor: {
        if (WifiService.errorMessage.length > 0)
            return Colors.red
        if (!WifiService.wifiEnabled)
            return Colors.muted
        if (root.connected)
            return Colors.green
        return Colors.accent
    }

    readonly property string heroTitle: {
        if (!WifiService.wifiEnabled)
            return "Wi-Fi off"
        if (root.connected)
            return WifiService.activeSsid
        if (WifiService.scanning)
            return "Searching…"
        return "Not connected"
    }

    readonly property string heroStatusText: {
        if (!WifiService.wifiEnabled)
            return "Wi-Fi off"
        if (root.connected)
            return "Connected"
        if (WifiService.scanning)
            return "Searching…"
        return "Not connected"
    }

    readonly property string heroMetaText: {
        if (WifiService.errorMessage.length > 0)
            return "Last action failed"
        if (root.powerPending)
            return root.powerPendingTarget ? "Turning Wi-Fi on…" : "Turning Wi-Fi off…"
        if (!WifiService.wifiEnabled)
            return "Select to turn Wi-Fi on"
        if (root.connected)
            return "Signal " + root.signalText(WifiService.activeSignal)
        return "Select a network to connect"
    }

    function sortedNetworkList() {
        const items = (WifiService.networks || []).slice()
        return items.sort((a, b) => {
            if (!!a.active !== !!b.active)
                return a.active ? -1 : 1
            if (!!a.known !== !!b.known)
                return a.known ? -1 : 1
            const signalDelta = Number(b.signal || 0) - Number(a.signal || 0)
            if (signalDelta !== 0)
                return signalDelta
            return String(a.ssid || "").localeCompare(String(b.ssid || ""))
        })
    }

    function securityText(network) {
        const security = String((network && network.security) ? network.security : "")
        return security.length > 0 ? security : "Open"
    }

    function signalText(signal) {
        return Math.max(0, Number(signal || 0)) + "%"
    }

    function signalGlyph(signal) {
        const value = Math.max(0, Number(signal || 0))
        if (value < 20)
            return "󰤯"
        if (value < 40)
            return "󰤟"
        if (value < 60)
            return "󰤢"
        if (value < 80)
            return "󰤥"
        return "󰤨"
    }

    function selectNetwork(network) {
        if (selectedNetwork !== null && selectedNetwork.ssid === network.ssid) {
            clearSelection()
            return
        }
        selectedNetwork = network
        passwordText = ""
        if (network.known)
            detailMode = "known"
        else if (String(network.security || "").length > 0)
            detailMode = "password"
        else
            detailMode = "open"
    }

    function clearSelection() {
        selectedNetwork = null
        detailMode = ""
        passwordText = ""
    }

    // A detail sheet for a row that is no longer rendered would describe
    // nothing, so any collapse back to the preview clears the selection.
    onShowAllNetworksChanged: if (!showAllNetworks) clearSelection()
    // Once the list fits in the preview there is nothing left to reveal; drop
    // the mode so a later scan cannot silently re-expand a stale view.
    onNetworksTruncatedChanged: if (!networksTruncated) showAllNetworks = false
    onExpandedChanged: {
        if (expanded)
            return
        clearSelection()
        showAllNetworks = false
    }
    onStandaloneChanged: if (standalone) expanded = true
    onVisibleChanged: if (visible && standalone) expanded = true

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingSm
        spacing: Theme.spacingSm

        // ── Layer 1 — hero: the connected network owns this block ─────────
        Rectangle {
            id: heroBlock
            Layout.fillWidth: true
            implicitHeight: heroRow.implicitHeight + Theme.spacingSm * 2
            radius: Theme.radiusLg
            color: heroClickArea.containsMouse
                   ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.60)
                   : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b,
                             WifiService.wifiEnabled ? 0.44 : 0.24)
            border.width: 0

            // Click/hover surface sits below the content so the chevron keeps its
            // own affordance while the rest of the hero toggles the module.
            MouseArea {
                id: heroClickArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // With the radio off the hero has no list to reveal, so the
                    // whole block is the power action instead of the expander.
                    if (!WifiService.wifiEnabled) {
                        root.requestPower(true)
                        return
                    }
                    if (root.standalone)
                        root.expanded = true
                    else
                        root.expanded = !root.expanded
                }
            }

            // Accent seam — the only rail in this module.
            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    topMargin: Theme.radiusLg
                    bottomMargin: Theme.radiusLg
                }
                width: Theme.accentSeamWidth
                radius: Theme.radiusPill
                color: root.heroStateColor
                opacity: WifiService.wifiEnabled ? 0.95 : 0.55
            }

            RowLayout {
                id: heroRow
                anchors {
                    fill: parent
                    leftMargin: Theme.spacingLg
                    rightMargin: Theme.spacingSm
                    topMargin: Theme.spacingSm
                    bottomMargin: Theme.spacingSm
                }
                spacing: Theme.spacingMd

                Rectangle {
                    id: signalPuck
                    Layout.preferredWidth: Math.max(puckColumn.implicitWidth, puckColumn.implicitHeight)
                    Layout.preferredHeight: Math.max(puckColumn.implicitWidth, puckColumn.implicitHeight)
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusMd
                    color: Qt.rgba(root.heroStateColor.r, root.heroStateColor.g, root.heroStateColor.b, 0.14)
                    border.width: 0

                    ColumnLayout {
                        id: puckColumn
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: WifiService.wifiEnabled ? root.signalGlyph(WifiService.activeSignal) : "󰤭"
                            color: root.heroStateColor
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.connected && WifiService.wifiEnabled
                            text: root.signalText(WifiService.activeSignal)
                            color: root.heroStateColor
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.spacingXs

                    Text {
                        Layout.fillWidth: true
                        text: root.heroStatusText
                        elide: Text.ElideRight
                        color: root.heroStateColor
                        font {
                            family: Colors.uiFont
                            pixelSize: Theme.fontSizeCaption
                            capitalization: Font.AllUppercase
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.heroTitle
                        elide: Text.ElideRight
                        color: Colors.textBright
                        font { family: Colors.displayFont; pixelSize: Theme.fontSizeBodyLg; weight: Font.DemiBold }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.heroMetaText
                        elide: Text.ElideRight
                        color: Colors.textDim
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                    }
                }

                // Radio power — the module's system switch. Quiet while the
                // radio is on, emphasized as the hero action while it is off.
                WifiPowerSwitch {
                    radioOn: WifiService.wifiEnabled
                    pending: root.powerPending
                    emphasis: !WifiService.wifiEnabled
                    actionLabel: root.powerPendingTarget ? "Turn on" : "Turn off"
                    onActivated: root.requestPower(!WifiService.wifiEnabled)
                }

                Rectangle {
                    id: chevronButton
                    visible: !root.standalone && WifiService.wifiEnabled
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusPill
                    color: chevronClickArea.containsMouse || root.expanded
                           ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
                           : "transparent"
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: root.expanded ? "⌃" : "⌄"
                        color: Colors.textDim
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                    }

                    MouseArea {
                        id: chevronClickArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: WifiService.errorMessage.length > 0
            text: WifiService.errorMessage
            wrapMode: Text.WordWrap
            color: Colors.red
            font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
        }

        // ── Layer 2 — nearby networks: secondary, denser, quieter ─────────
        ColumnLayout {
            id: nearbyGroup
            Layout.fillWidth: true
            visible: root.expanded && WifiService.wifiEnabled
            spacing: Theme.spacingXs

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.bottomMargin: Theme.spacingXs
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
                radius: Theme.radiusPill
                border.width: 0
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.spacingXs
                spacing: Theme.spacingSm

                Text {
                    text: "Nearby networks"
                    color: Colors.textDim
                    font {
                        family: Colors.uiFont
                        pixelSize: Theme.fontSizeCaption
                        capitalization: Font.AllUppercase
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                }

                WifiPillAction {
                    Layout.alignment: Qt.AlignVCenter
                    label: root.showAllNetworks
                           ? "Show top " + root.visibleNetworkCount
                           : "Show all " + root.sortedNetworks.length
                    accentColor: Colors.accent
                    quiet: true
                    visible: root.networksTruncated
                    onTriggered: root.showAllNetworks = !root.showAllNetworks
                }

                WifiPillAction {
                    Layout.alignment: Qt.AlignVCenter
                    label: WifiService.scanning ? "Scanning…" : "Scan"
                    glyph: "󰑓"
                    accentColor: Colors.accent
                    quiet: true
                    enabled: !WifiService.scanning
                    onTriggered: WifiService.scan()
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingXs
                visible: root.visibleNetworks.length === 0
                text: WifiService.scanning ? "Searching…" : "No networks found"
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }

            Repeater {
                model: root.visibleNetworks

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    WifiNetworkRow {
                        Layout.fillWidth: true
                        glyphText: root.signalGlyph(modelData.signal)
                        titleText: modelData.ssid && String(modelData.ssid).length > 0
                                   ? modelData.ssid : "Unnamed network"
                        metaText: root.securityText(modelData) + (modelData.known ? " • Saved" : "")
                        trailingText: modelData.active ? "Active" : root.signalText(modelData.signal)
                        isActive: !!modelData.active
                        isSelected: root.selectedNetwork !== null
                                    && root.selectedNetwork.ssid === modelData.ssid
                        onRowSelected: root.selectNetwork(modelData)
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacingSm
                        active: root.selectedNetwork !== null
                                && root.selectedNetwork.ssid === modelData.ssid
                        visible: active
                        sourceComponent: wifiDetailSheet
                    }
                }
            }

            // ── Layer 3 — selection detail sheet ───────────────────────
            Component {
                id: wifiDetailSheet

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: detailColumn.implicitHeight + Theme.spacingMd * 2
                radius: Theme.radiusLg
                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.10)
                border.width: 0

                ColumnLayout {
                    id: detailColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: root.selectedNetwork ? (root.selectedNetwork.ssid || "Network") : "Network"
                                elide: Text.ElideRight
                                color: Colors.textBright
                                font { family: Colors.displayFont; pixelSize: Theme.fontSizeBodyLg; weight: Font.DemiBold }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.selectedNetwork
                                      ? (root.signalText(root.selectedNetwork.signal) + " • " + root.securityText(root.selectedNetwork) + (root.selectedNetwork.known ? " • Saved" : ""))
                                      : ""
                                elide: Text.ElideRight
                                color: Colors.textDim
                                font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                            }
                        }

                        WifiPillAction {
                            Layout.alignment: Qt.AlignVCenter
                            label: "Cancel"
                            accentColor: Colors.muted
                            quiet: true
                            onTriggered: root.clearSelection()
                        }
                    }

                    TextInput {
                        visible: root.detailMode === "password"
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacingXs
                        Layout.preferredHeight: 30
                        text: root.passwordText
                        echoMode: TextInput.Password
                        color: Colors.text
                        selectionColor: Colors.accent
                        selectedTextColor: Colors.background
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.passwordText = text

                        Rectangle {
                            anchors.fill: parent
                            z: -1
                            radius: Theme.radiusSm
                            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.55)
                            border.width: Theme.dashboardBodyBorderWidth
                            border.color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingSm
                            visible: parent.text.length === 0 && !parent.activeFocus
                            text: "Password"
                            color: Colors.muted
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                        }
                    }

                    Text {
                        visible: root.detailMode === "forget"
                        Layout.fillWidth: true
                        text: "Forget this saved network?"
                        color: Colors.orange
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacingXs
                        spacing: Theme.spacingSm

                        WifiPillAction {
                            visible: root.detailMode === "known"
                            Layout.fillWidth: true
                            label: "Connect"
                            accentColor: Colors.accent
                            onTriggered: {
                                WifiService.connectKnown(root.selectedNetwork.ssid)
                                root.clearSelection()
                            }
                        }

                        WifiPillAction {
                            visible: root.detailMode === "known"
                            Layout.fillWidth: true
                            label: "Forget"
                            accentColor: Colors.orange
                            onTriggered: root.detailMode = "forget"
                        }

                        WifiPillAction {
                            visible: root.detailMode === "forget"
                            Layout.fillWidth: true
                            label: "Confirm forget"
                            accentColor: Colors.red
                            onTriggered: {
                                WifiService.forget(root.selectedNetwork.uuid)
                                root.clearSelection()
                            }
                        }

                        WifiPillAction {
                            visible: root.detailMode === "forget"
                            Layout.fillWidth: true
                            label: "Keep"
                            accentColor: Colors.muted
                            onTriggered: root.detailMode = "known"
                        }

                        WifiPillAction {
                            visible: root.detailMode === "password" || root.detailMode === "open"
                            Layout.fillWidth: true
                            label: "Connect"
                            accentColor: Colors.accent
                            onTriggered: {
                                WifiService.connectWithPassword(root.selectedNetwork.ssid,
                                                                root.detailMode === "open" ? "" : root.passwordText)
                                root.clearSelection()
                            }
                        }
                    }
                }
            }
            }
        }
    }

    // Secondary list row: dense, quiet, tint only on hover/active/selected.
    component WifiNetworkRow: Rectangle {
        id: networkRow

        property string glyphText: "󰤨"
        property string titleText: "Unnamed network"
        property string metaText: ""
        property string trailingText: ""
        property bool isActive: false
        property bool isSelected: false

        signal rowSelected()

        Layout.fillWidth: true
        implicitHeight: rowContent.implicitHeight + Theme.spacingXs * 2
        radius: Theme.radiusMd
        color: networkRow.isSelected
               ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
               : (networkRow.isActive
                  ? Qt.rgba(Colors.green.r, Colors.green.g, Colors.green.b, 0.10)
                  : (rowClickArea.containsMouse ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.40) : "transparent"))
        border.width: 0

        RowLayout {
            id: rowContent
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingSm
            anchors.rightMargin: Theme.spacingSm
            anchors.topMargin: Theme.spacingXs
            anchors.bottomMargin: Theme.spacingXs
            spacing: Theme.spacingSm

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: networkRow.glyphText
                color: networkRow.isActive ? Colors.green : Colors.muted
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: networkRow.titleText
                    elide: Text.ElideRight
                    color: networkRow.isActive ? Colors.green : Colors.text
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel; weight: Font.DemiBold }
                }

                Text {
                    Layout.fillWidth: true
                    visible: networkRow.metaText.length > 0
                    text: networkRow.metaText
                    elide: Text.ElideRight
                    color: Colors.textDim
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: networkRow.trailingText
                color: networkRow.isActive ? Colors.green : Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
            }
        }

        MouseArea {
            id: rowClickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: networkRow.rowSelected()
        }
    }

    // Clear the outstanding power request as soon as the service reports the
    // state we asked for; the timer is the fallback when it never arrives.
    Connections {
        target: WifiService
        function onWifiEnabledChanged() {
            if (!root.powerPending || WifiService.wifiEnabled !== root.powerPendingTarget)
                return
            root.powerPending = false
            powerSettleTimer.stop()
        }
    }

    Timer {
        id: powerSettleTimer
        interval: root.powerSettleMs
        onTriggered: root.powerPending = false
    }

    // Radio power — the module's system switch.
    //
    // One control at two weights, so power is always reachable and never reads
    // as a toggle bolted onto a card:
    //   quiet    — radio on: power glyph over a thin accent rail, secondary to
    //              the hero's network identity and borderless like the rest of
    //              the panel chrome.
    //   emphasis — radio off: the same rail widens under a labelled accent
    //              slab, because powering the radio back up is the only action
    //              this panel has left.
    // While a request is in flight the rail turns into a sweeping track and
    // the control stops accepting clicks.
    component WifiPowerSwitch: Rectangle {
        id: powerSwitch

        property bool radioOn: false
        property bool pending: false
        property bool emphasis: false
        property string actionLabel: "Power"

        signal activated()

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: powerContent.implicitWidth + Theme.spacingMd
        implicitHeight: powerContent.implicitHeight + Theme.spacingXs * 2
        radius: powerSwitch.emphasis ? Theme.radiusMd : Theme.radiusPill
        opacity: powerSwitch.pending ? 0.72 : 1.0
        color: powerSwitch.emphasis
               ? (powerClickArea.containsMouse
                  ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.24)
                  : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14))
               : (powerClickArea.containsMouse
                  ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.10)
                  : "transparent")
        border.width: 0

        RowLayout {
            id: powerContent
            anchors.centerIn: parent
            spacing: Theme.spacingXs

            ColumnLayout {
                id: powerStack
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.spacingXs

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰐥"
                    color: powerSwitch.emphasis
                           ? Colors.accent
                           : (powerSwitch.radioOn ? Colors.textDim : Colors.muted)
                    font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
                }

                // The rail: this module's single "system switch" signature.
                Rectangle {
                    id: powerRail
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: powerSwitch.emphasis
                                           ? Theme.fontSizeIcon + Theme.spacingMd
                                           : Theme.fontSizeBody + Theme.spacingXs
                    Layout.preferredHeight: Theme.accentSeamWidth
                    radius: Theme.radiusPill
                    color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
                    border.width: 0

                    Rectangle {
                        visible: !powerSwitch.pending
                        anchors.fill: parent
                        radius: Theme.radiusPill
                        color: powerSwitch.radioOn ? Colors.accent : Colors.muted
                        opacity: powerSwitch.radioOn ? 0.95 : 0.55
                    }

                    // In-flight sweep: the request is running, not dead.
                    Rectangle {
                        id: powerRailSweep
                        visible: powerSwitch.pending
                        width: Theme.spacingSm
                        height: powerRail.height
                        radius: Theme.radiusPill
                        color: Colors.accent

                        SequentialAnimation on x {
                            running: powerRailSweep.visible
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 0
                                to: Math.max(0, powerRail.width - powerRailSweep.width)
                                duration: Theme.animNormal
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                from: Math.max(0, powerRail.width - powerRailSweep.width)
                                to: 0
                                duration: Theme.animNormal
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: powerSwitch.emphasis
                text: powerSwitch.actionLabel
                color: Colors.accent
                font {
                    family: Colors.uiFont
                    pixelSize: Theme.fontSizeCaption
                    capitalization: Font.AllUppercase
                    weight: Font.DemiBold
                }
            }
        }

        MouseArea {
            id: powerClickArea
            anchors.fill: parent
            enabled: !powerSwitch.pending
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: powerSwitch.activated()
        }
    }

    // Borderless tinted pill: quiet variant for secondary actions.
    component WifiPillAction: Rectangle {
        id: pillAction

        property string label: ""
        property string glyph: ""
        property color accentColor: Colors.accent
        property bool quiet: false

        signal triggered()

        implicitWidth: pillRow.implicitWidth + Theme.spacingMd
        implicitHeight: 26
        radius: Theme.radiusPill
        opacity: enabled ? 1.0 : 0.55
        color: pillAction.quiet
               ? (pillClickArea.containsMouse
                  ? Qt.rgba(pillAction.accentColor.r, pillAction.accentColor.g, pillAction.accentColor.b, 0.16)
                  : "transparent")
               : (pillClickArea.containsMouse
                  ? Qt.rgba(pillAction.accentColor.r, pillAction.accentColor.g, pillAction.accentColor.b, 0.24)
                  : Qt.rgba(pillAction.accentColor.r, pillAction.accentColor.g, pillAction.accentColor.b, 0.14))
        border.width: 0

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spacingXs

            Text {
                visible: pillAction.glyph.length > 0
                text: pillAction.glyph
                color: pillAction.quiet ? pillAction.accentColor : Colors.text
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeLabel }
            }

            Text {
                text: pillAction.label
                color: pillAction.quiet ? pillAction.accentColor : Colors.text
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }
        }

        MouseArea {
            id: pillClickArea
            anchors.fill: parent
            enabled: pillAction.enabled
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: pillAction.triggered()
        }
    }
}
