import QtQuick
import QtQuick.Layouts
import "../services"
import "../theme"

// Bluetooth specialty module.
//
// Layered composition (same grammar as the Wi-Fi card):
//   Layer 1 — hero block anchored on adapter state: powered flag, connected
//             count and discovery state, with the module's only accent seam
//             and a dedicated state puck. The hero's trailing edge carries the
//             adapter power switch, which changes weight with adapter state:
//               on  — quiet borderless rail control, secondary to identity.
//               off — the hero itself becomes the action and the switch is
//                     emphasized, so powering the adapter back up is reachable
//                     without a list that cannot render.
//   Layer 2 — primary "Connected devices" group, visually dominant, with
//             battery as a compact secondary readout.
//   Layer 3 — quiet "Available devices" group; discovery and the overflow
//             reveal live in its header.
//   Layer 4 — lightweight detail sheet for pair / connect / disconnect / forget.
//
// Geometry comes from Theme.qml, color and type from Colors.qml.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + Theme.spacingSm * 2
    radius: Theme.radiusLg
    color: Theme.rightPanelCardSurface(Colors.backgroundAlt)
    border.width: Theme.dashboardBodyBorderWidth
    border.color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder * 0.55)

    property bool expanded: false
    property bool standalone: false
    property string selectedAddress: ""
    property string detailMode: "" // "connected" | "available" | "forget" | "pair" | "pairing"
    property string forgetReturnMode: ""
    // Adapter power is requested through the service, which refreshes on its
    // own cadence; these track the outstanding request so the affordance never
    // reads as dead and never queues a second call while one is running.
    property bool powerPending: false
    property bool powerPendingTarget: false

    readonly property int visibleDeviceCount: 6
    // Overflow is a view mode, not a different list: the preview slice stays
    // the default and the group-header control reveals the rest in place.
    property bool showAllDevices: false
    readonly property int hiddenDeviceCount: Math.max(0, availableDevices.length - visibleDeviceCount)
    readonly property bool devicesTruncated: hiddenDeviceCount > 0

    // A power change is not instant: `bluetoothctl power` answers, then the
    // service refresh has to observe it. Settle window is three refresh cycles,
    // derived from Theme.animSlow so it stays inside the shell's timing tokens.
    readonly property int powerSettleMs: Theme.animSlow * 30

    function requestPower(nextState) {
        if (powerPending)
            return
        powerPendingTarget = nextState
        powerPending = true
        clearSelection()
        BluetoothService.setBluetoothEnabled(nextState)
        powerSettleTimer.restart()
    }
    readonly property int connectedCount: (BluetoothService.connectedDevices || []).length
    readonly property var availableDevices: availableDeviceList()
    readonly property var visibleAvailableDevices: showAllDevices
                                                   ? availableDevices
                                                   : availableDevices.slice(0, visibleDeviceCount)
    readonly property var selectedDevice: selectedAddress.length > 0 ? deviceByAddress(selectedAddress) : null
    readonly property bool selectionConnected: selectedDevice !== null && !!selectedDevice.connected
    readonly property bool selectionPaired: selectedDevice !== null
                                            && (!!selectedDevice.paired || !!selectedDevice.trusted)

    // Single source of truth for "state color": seam, status label and puck.
    readonly property color heroStateColor: {
        if (BluetoothService.errorMessage.length > 0)
            return Colors.red
        if (!BluetoothService.bluetoothEnabled)
            return Colors.muted
        if (root.connectedCount > 0)
            return Colors.green
        return Colors.accent
    }

    readonly property string heroTitle: {
        if (!BluetoothService.bluetoothEnabled)
            return "Bluetooth off"
        if (root.connectedCount > 0)
            return root.deviceName(BluetoothService.connectedDevices[0])
        if (BluetoothService.discovering)
            return "Searching…"
        return "Not connected"
    }

    readonly property string heroStatusText: {
        if (!BluetoothService.bluetoothEnabled)
            return "Adapter off"
        if (root.connectedCount > 1)
            return root.connectedCount + " Connected"
        if (root.connectedCount > 0)
            return "Connected"
        if (BluetoothService.discovering)
            return "Discovering"
        return "Ready"
    }

    readonly property string heroMetaText: {
        if (BluetoothService.errorMessage.length > 0)
            return "Last action failed"
        if (root.powerPending)
            return root.powerPendingTarget ? "Turning Bluetooth on…" : "Turning Bluetooth off…"
        if (!BluetoothService.bluetoothEnabled)
            return "Turn Bluetooth on to manage devices"
        if (root.connectedCount > 1)
            return "+" + (root.connectedCount - 1) + " more connected"
        if (root.connectedCount === 1) {
            const battery = root.batteryText(BluetoothService.connectedDevices[0])
            return battery.length > 0 ? "Battery " + battery : "Tap to manage this device"
        }
        if (BluetoothService.discovering)
            return "Scanning for nearby devices"
        if (root.availableDevices.length > 0)
            return root.availableDevices.length + " devices available"
        return "No devices found yet"
    }

    function availableDeviceList() {
        const connected = BluetoothService.connectedDevices || []
        const items = (BluetoothService.availableDevices || []).slice()
        const filtered = []
        for (let i = 0; i < items.length; i++) {
            let item = items[i]
            if (!item || !item.address)
                continue
            let isConnected = false
            for (let j = 0; j < connected.length; j++) {
                if (connected[j] && connected[j].address === item.address) {
                    isConnected = true
                    break
                }
            }
            if (!isConnected)
                filtered.push(item)
        }
        return filtered.sort((a, b) => {
            if (!!a.paired !== !!b.paired)
                return a.paired ? -1 : 1
            if (!!a.trusted !== !!b.trusted)
                return a.trusted ? -1 : 1
            return root.deviceName(a).localeCompare(root.deviceName(b))
        })
    }

    function deviceByAddress(address) {
        const allDevices = (BluetoothService.connectedDevices || []).concat(BluetoothService.availableDevices || [])
        for (let i = 0; i < allDevices.length; i++) {
            if (allDevices[i] && allDevices[i].address === address)
                return allDevices[i]
        }
        return null
    }

    function deviceName(device) {
        if (device && device.name && String(device.name).length > 0)
            return device.name
        return "Bluetooth device"
    }

    function deviceIcon(device) {
        const icon = String((device && device.icon) ? device.icon : "").toLowerCase()
        if (icon.indexOf("head") >= 0 || icon.indexOf("audio") >= 0)
            return "󰋋"
        if (icon.indexOf("input") >= 0 || icon.indexOf("keyboard") >= 0)
            return "󰌌"
        if (icon.indexOf("mouse") >= 0)
            return "󰍽"
        if (icon.indexOf("phone") >= 0)
            return "󰏲"
        if (icon.indexOf("computer") >= 0)
            return "󰍹"
        return "󰂯"
    }

    function batteryText(device) {
        if (!device || device.battery === null || device.battery === undefined)
            return ""
        return Number(device.battery) + "%"
    }

    function batteryGlyph(batteryText) {
        const value = Math.max(0, Number(String(batteryText || "").replace("%", "")))
        if (value < 20)
            return "󰂎"
        if (value < 40)
            return "󰁺"
        if (value < 60)
            return "󰁻"
        if (value < 80)
            return "󰁼"
        return "󰁹"
    }

    function stateText(device) {
        if (!device)
            return "Unknown"
        if (device.connected)
            return "Connected"
        if (root.selectedAddress === device.address && root.detailMode === "pairing")
            return "Pairing…"
        if (device.paired)
            return "Paired"
        if (device.trusted)
            return "Trusted"
        return "Not paired"
    }

    function selectConnected(device) {
        if (selectedAddress === device.address) {
            clearSelection()
            return
        }
        selectedAddress = device.address || ""
        detailMode = "connected"
    }

    function selectAvailable(device) {
        if (device.paired || device.trusted) {
            selectedAddress = device.address || ""
            BluetoothService.connectDevice(selectedAddress)
            clearSelection()
        } else if (selectedAddress === device.address) {
            clearSelection()
        } else {
            selectedAddress = device.address || ""
            detailMode = "pair"
        }
    }

    function requestForget() {
        forgetReturnMode = detailMode.length > 0 ? detailMode : "connected"
        detailMode = "forget"
    }

    function startPairing() {
        if (!selectedDevice)
            return
        detailMode = "pairing"
        BluetoothService.pairDevice(selectedDevice.address)
    }

    function clearSelection() {
        selectedAddress = ""
        detailMode = ""
        forgetReturnMode = ""
    }

    // A detail sheet for a row that is no longer rendered would describe
    // nothing, so any collapse back to the preview clears the selection.
    onShowAllDevicesChanged: if (!showAllDevices) clearSelection()
    // Once the list fits in the preview there is nothing left to reveal; drop
    // the mode so a later discovery cannot silently re-expand a stale view.
    onDevicesTruncatedChanged: if (!devicesTruncated) showAllDevices = false
    onExpandedChanged: {
        if (expanded)
            return
        clearSelection()
        showAllDevices = false
    }
    onStandaloneChanged: if (standalone) expanded = true
    onVisibleChanged: {
        if (!visible)
            clearSelection()
        else if (standalone)
            expanded = true
    }

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingSm
        spacing: Theme.spacingSm

        // ── Layer 1 — hero: adapter state owns this block ─────────────────
        Rectangle {
            id: heroBlock
            Layout.fillWidth: true
            implicitHeight: heroRow.implicitHeight + Theme.spacingSm * 2
            radius: Theme.radiusLg
            color: heroClickArea.containsMouse
                   ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.60)
                   : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b,
                             BluetoothService.bluetoothEnabled ? 0.44 : 0.24)
            border.width: 0

            // Click/hover surface sits below the content so the chevron keeps its
            // own affordance while the rest of the hero toggles the module.
            MouseArea {
                id: heroClickArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // With the adapter off the hero has no device list to reveal,
                    // so the whole block is the power action instead of the
                    // expander.
                    if (!BluetoothService.bluetoothEnabled) {
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
                opacity: BluetoothService.bluetoothEnabled ? 0.95 : 0.55
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
                    id: adapterPuck
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
                            text: BluetoothService.bluetoothEnabled ? "󰂯" : "󰂲"
                            color: root.heroStateColor
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.connectedCount > 0 && BluetoothService.bluetoothEnabled
                            text: root.connectedCount + ""
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

                // Adapter power — the module's system switch. Quiet while the
                // adapter is on, emphasized as the hero action while it is off.
                BtPowerSwitch {
                    radioOn: BluetoothService.bluetoothEnabled
                    pending: root.powerPending
                    emphasis: !BluetoothService.bluetoothEnabled
                    actionLabel: root.powerPendingTarget ? "Turn on" : "Turn off"
                    onActivated: root.requestPower(!BluetoothService.bluetoothEnabled)
                }

                Rectangle {
                    id: chevronButton
                    visible: !root.standalone && BluetoothService.bluetoothEnabled
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusMd
                    color: Theme.buttonFill(Colors.accent, false,
                                            chevronClickArea.pressed
                                            ? "pressed"
                                            : (chevronClickArea.containsMouse || root.expanded ? "hover" : "rest"))
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
            visible: BluetoothService.errorMessage.length > 0
            text: BluetoothService.errorMessage
            wrapMode: Text.WordWrap
            color: Colors.red
            font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
        }

        // ── Layer 2 — connected devices: the primary group ───────────────
        ColumnLayout {
            id: connectedGroup
            Layout.fillWidth: true
            visible: root.expanded && BluetoothService.bluetoothEnabled && root.connectedCount > 0
            spacing: Theme.spacingSm

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
                    text: "Connected devices"
                    color: Colors.textDim
                    font {
                        family: Colors.uiFont
                        pixelSize: Theme.fontSizeCaption
                        weight: Font.DemiBold
                        capitalization: Font.MixedCase
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.connectedCount + " active"
                    color: Colors.green
                    font {
                        family: Colors.uiFont
                        pixelSize: Theme.fontSizeCaption
                        capitalization: Font.MixedCase
                    }
                }
            }

            Repeater {
                model: BluetoothService.connectedDevices || []

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    BtDeviceRow {
                        Layout.fillWidth: true
                        primary: true
                        glyphText: root.deviceIcon(modelData)
                        titleText: root.deviceName(modelData)
                        metaText: root.stateText(modelData)
                        batteryText: root.batteryText(modelData)
                        batteryGlyphText: root.batteryGlyph(root.batteryText(modelData))
                        isConnected: true
                        isSelected: root.selectedAddress === modelData.address
                        onRowSelected: root.selectConnected(modelData)
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacingSm
                        active: root.selectedAddress === modelData.address
                        visible: active
                        sourceComponent: bluetoothDetailSheet
                    }
                }
            }
        }

        // ── Layer 3 — available devices: secondary, denser, quieter ──────
        ColumnLayout {
            id: availableGroup
            Layout.fillWidth: true
            visible: root.expanded && BluetoothService.bluetoothEnabled
            spacing: Theme.spacingSm

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
                    text: "Available devices"
                    color: Colors.textDim
                    font {
                        family: Colors.uiFont
                        pixelSize: Theme.fontSizeCaption
                        weight: Font.DemiBold
                        capitalization: Font.MixedCase
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                }

                BtPillAction {
                    Layout.alignment: Qt.AlignVCenter
                    label: root.showAllDevices
                           ? "Show top " + root.visibleDeviceCount
                           : "Show all " + root.availableDevices.length
                    accentColor: Colors.accent
                    quiet: true
                    visible: root.devicesTruncated
                    onTriggered: root.showAllDevices = !root.showAllDevices
                }

                // Discovery trigger: the button starts the service's bounded
                // bluetoothctl scan; the label and enabled state follow the
                // optimistic discovering flag while that scan is in flight.
                BtPillAction {
                    Layout.alignment: Qt.AlignVCenter
                    label: BluetoothService.discovering ? "Scanning…" : "Scan"
                    glyph: "󰑓"
                    accentColor: Colors.accent
                    quiet: true
                    enabled: !BluetoothService.discovering
                    onTriggered: BluetoothService.scan()
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingXs
                visible: root.visibleAvailableDevices.length === 0
                text: BluetoothService.discovering ? "Searching for devices…" : "No devices found"
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }

            Repeater {
                model: root.visibleAvailableDevices

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    BtDeviceRow {
                        Layout.fillWidth: true
                        glyphText: root.deviceIcon(modelData)
                        titleText: root.deviceName(modelData)
                        metaText: root.stateText(modelData) + (modelData.paired ? " • Saved" : "")
                        batteryText: root.batteryText(modelData)
                        batteryGlyphText: root.batteryGlyph(root.batteryText(modelData))
                        isSelected: root.selectedAddress === modelData.address
                        onRowSelected: root.selectAvailable(modelData)
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacingSm
                        active: root.selectedAddress === modelData.address
                        visible: active
                        sourceComponent: bluetoothDetailSheet
                    }
                }
            }
        }

        // ── Layer 4 — selection detail sheet ─────────────────────────────
        Component {
            id: bluetoothDetailSheet

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: detailColumn.implicitHeight + Theme.spacingMd * 2
                radius: Theme.radiusLg
                color: Theme.surfaceNested(Colors.surface)
                border.width: 0

            ColumnLayout {
                id: detailColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingSm
                spacing: Theme.spacingXs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedDevice ? root.deviceName(root.selectedDevice) : "Bluetooth device"
                            elide: Text.ElideRight
                            color: Colors.textBright
                            font { family: Colors.displayFont; pixelSize: Theme.fontSizeBodyLg; weight: Font.DemiBold }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedDevice
                                  ? (root.stateText(root.selectedDevice)
                                     + (root.batteryText(root.selectedDevice).length > 0
                                        ? " • Battery " + root.batteryText(root.selectedDevice) : ""))
                                  : ""
                            elide: Text.ElideRight
                            color: Colors.textDim
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedDevice ? String(root.selectedDevice.address || "") : ""
                            elide: Text.ElideRight
                            color: Colors.muted
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeCaption }
                        }
                    }

                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacingXs
                    Layout.preferredHeight: 1
                    color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
                    radius: Theme.radiusPill
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.detailMode === "pairing" && !root.selectionConnected
                    text: "Pairing… check the device for confirmation."
                    color: Colors.accent
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.detailMode === "forget"
                    text: "Forget this Bluetooth device?"
                    color: Colors.orange
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacingXs
                    spacing: Theme.spacingSm

                    BtPillAction {
                        visible: root.detailMode !== "forget" && root.detailMode !== "pairing"
                                 && !root.selectionConnected && !root.selectionPaired
                        Layout.fillWidth: true
                        label: "Pair"
                        primary: true
                        accentColor: Colors.accent
                        onTriggered: root.startPairing()
                    }

                    BtPillAction {
                        visible: root.detailMode !== "forget" && root.selectionPaired && !root.selectionConnected
                        Layout.fillWidth: true
                        label: "Connect"
                        primary: true
                        accentColor: Colors.accent
                        onTriggered: {
                            if (root.selectedDevice)
                                BluetoothService.connectDevice(root.selectedDevice.address)
                            root.clearSelection()
                        }
                    }

                    BtPillAction {
                        visible: root.detailMode !== "forget" && root.selectionConnected
                        Layout.fillWidth: true
                        label: "Disconnect"
                        primary: true
                        accentColor: Colors.yellow
                        onTriggered: {
                            if (root.selectedDevice)
                                BluetoothService.disconnectDevice(root.selectedDevice.address)
                            root.clearSelection()
                        }
                    }

                    BtPillAction {
                        visible: root.detailMode !== "forget" && (root.selectionConnected || root.selectionPaired)
                        Layout.fillWidth: true
                        label: "Forget"
                        primary: false
                        accentColor: Colors.muted
                        onTriggered: root.requestForget()
                    }

                    BtPillAction {
                        visible: root.detailMode === "forget"
                        Layout.fillWidth: true
                        label: "Confirm forget"
                        primary: true
                        accentColor: Colors.red
                        onTriggered: {
                            if (root.selectedDevice)
                                BluetoothService.forgetDevice(root.selectedDevice.address)
                            root.clearSelection()
                        }
                    }

                }
            }
            }
        }
    }

    // Device row: dominant when primary (connected), quiet otherwise.
    component BtDeviceRow: Rectangle {
        id: deviceRow

        property bool primary: false
        property string glyphText: "󰂯"
        property string titleText: "Bluetooth device"
        property string metaText: ""
        property string batteryText: ""
        property string batteryGlyphText: "󰁹"
        property bool isConnected: false
        property bool isSelected: false

        signal rowSelected()

        Layout.fillWidth: true
        implicitHeight: rowContent.implicitHeight + (deviceRow.primary ? Theme.spacingSm * 2 : Theme.spacingXs * 2)
        radius: Theme.radiusMd
        color: deviceRow.isSelected
               ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.34)
               : (deviceRow.isConnected
                  ? Qt.rgba(Colors.green.r, Colors.green.g, Colors.green.b, 0.10)
                  : (rowClickArea.containsMouse ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.24) : "transparent"))
        border.width: 0

        Rectangle {
            visible: deviceRow.isSelected
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                topMargin: Theme.radiusMd
                bottomMargin: Theme.radiusMd
            }
            width: 2
            radius: Theme.radiusPill
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.55)
        }

        RowLayout {
            id: rowContent
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingSm
            anchors.rightMargin: Theme.spacingSm
            anchors.topMargin: deviceRow.primary ? Theme.spacingSm : Theme.spacingXs
            anchors.bottomMargin: deviceRow.primary ? Theme.spacingSm : Theme.spacingXs
            spacing: Theme.spacingSm

            Rectangle {
                Layout.preferredWidth: deviceRow.primary ? Theme.fontSizeIcon + Theme.spacingMd : Theme.fontSizeBody + Theme.spacingXs
                Layout.preferredHeight: deviceRow.primary ? Theme.fontSizeIcon + Theme.spacingMd : Theme.fontSizeBody + Theme.spacingXs
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.radiusMd
                color: Qt.rgba(deviceRow.isConnected ? Colors.green.r : Colors.muted.r,
                               deviceRow.isConnected ? Colors.green.g : Colors.muted.g,
                               deviceRow.isConnected ? Colors.green.b : Colors.muted.b,
                               deviceRow.primary ? 0.14 : 0.08)
                border.width: 0

                Text {
                    anchors.centerIn: parent
                    text: deviceRow.glyphText
                    color: deviceRow.isSelected ? Colors.accent : (deviceRow.isConnected ? Colors.green : (deviceRow.primary ? Colors.text : Colors.muted))
                    font {
                        family: Colors.monoFont
                        pixelSize: deviceRow.primary ? Theme.fontSizeBodyLg : Theme.fontSizeBody
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: deviceRow.titleText
                    elide: Text.ElideRight
                    color: deviceRow.isSelected ? Colors.textBright : (deviceRow.isConnected ? Colors.textBright : (deviceRow.primary ? Colors.text : Colors.textDim))
                    font {
                        family: Colors.uiFont
                        pixelSize: deviceRow.primary ? Theme.fontSizeBody : Theme.fontSizeLabel
                        weight: deviceRow.primary ? Font.DemiBold : Font.Normal
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: deviceRow.metaText.length > 0
                    text: deviceRow.metaText
                    elide: Text.ElideRight
                    color: deviceRow.primary ? Colors.textDim : Colors.muted
                    font {
                        family: Colors.uiFont
                        pixelSize: deviceRow.primary ? Theme.fontSizeLabel : Theme.fontSizeCaption
                        capitalization: deviceRow.primary ? Font.MixedCase : Font.AllUppercase
                    }
                }
            }

            // Battery is a compact secondary readout, never a headline.
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                visible: deviceRow.batteryText.length > 0
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: deviceRow.batteryGlyphText
                    color: deviceRow.primary ? Colors.textDim : Colors.muted
                    font { family: Colors.monoFont; pixelSize: Theme.fontSizeLabel }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: deviceRow.batteryText
                    color: deviceRow.primary ? Colors.textDim : Colors.muted
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                }
            }
        }

        MouseArea {
            id: rowClickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: deviceRow.rowSelected()
        }
    }

    // Clear the outstanding power request as soon as the service reports the
    // state we asked for; the timer is the fallback when it never arrives.
    Connections {
        target: BluetoothService
        function onBluetoothEnabledChanged() {
            if (!root.powerPending || BluetoothService.bluetoothEnabled !== root.powerPendingTarget)
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

    // Adapter power — the module's system switch.
    //
    // One control at two weights, so power is always reachable and never reads
    // as a toggle bolted onto a card:
    //   quiet    — adapter on: power glyph over a thin accent rail, secondary
    //              to device identity and borderless like the rest of the
    //              panel chrome.
    //   emphasis — adapter off: the same rail widens under a labelled accent
    //              slab, because powering the adapter back up is the only
    //              action this panel has left.
    // While a request is in flight the rail turns into a sweeping track and the
    // control stops accepting clicks.
    component BtPowerSwitch: Rectangle {
        id: powerSwitch

        property bool radioOn: false
        property bool pending: false
        property bool emphasis: false
        property string actionLabel: "Power"

        signal activated()

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: powerContent.implicitWidth + Theme.spacingMd
        implicitHeight: powerContent.implicitHeight + Theme.spacingXs * 2
        radius: Theme.radiusMd
        opacity: powerSwitch.pending ? 0.72 : 1.0
        color: Theme.buttonFill(powerSwitch.emphasis ? Colors.accent : Colors.muted,
                                powerSwitch.emphasis,
                                powerClickArea.pressed
                                ? "pressed"
                                : (powerClickArea.containsMouse ? "hover" : "rest"))
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

    // Borderless tinted button: quiet variant for secondary actions.
    component BtPillAction: Rectangle {
        id: pillAction

        property string label: ""
        property string glyph: ""
        property color accentColor: Colors.accent
        property bool quiet: false
        property bool primary: false

        signal triggered()

        implicitWidth: pillRow.implicitWidth + Theme.spacingMd
        implicitHeight: 26
        radius: Theme.radiusSm
        color: !enabled ? Colors.base02
               : Theme.buttonFill(pillAction.accentColor, pillAction.primary,
                                  pillClickArea.pressed ? "pressed" : (pillClickArea.containsMouse ? "hover" : "rest"))
        border.width: pillAction.primary ? Theme.dashboardBodyBorderWidth : 0
        border.color: pillAction.primary
                      ? Qt.rgba(pillAction.accentColor.r, pillAction.accentColor.g, pillAction.accentColor.b, Theme.opacityBorder * 0.8)
                      : "transparent"

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
