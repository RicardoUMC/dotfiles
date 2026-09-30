import QtQuick
import QtQuick.Layouts
import "../services"
import "../theme"

// Audio specialty module.
//
// Layered composition, following the grammar established by WifiControlCard:
//   Layer 1 — hero block for the active output device: the module's only
//             accent seam, a state puck, and uppercase eyebrow labels.
//   Layer 2 — primary volume control as one inset slab; mute stays a
//             separate borderless pill affordance.
//   Layer 3 — quiet, dense "Routing" group for input selection and the
//             remaining output devices, opened by a hairline seam.
//
// Geometry comes from Theme.qml, color and type from Colors.qml.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + Theme.spacingSm * 2
    radius: Theme.radiusLg
    color: Qt.rgba(Colors.backgroundAlt.r, Colors.backgroundAlt.g, Colors.backgroundAlt.b,
                   AudioService.outputMuted ? 0.18 : 0.30)
    border.width: 0

    property bool panelOpen: false
    property bool standalone: false

    readonly property var defaultOutput: deviceById(AudioService.outputs || [], AudioService.defaultOutputId)
    readonly property var defaultInput: deviceById(AudioService.inputs || [], AudioService.defaultInputId)
    readonly property string outputName: defaultOutput
                                         ? defaultOutput.name
                                         : ((AudioService.outputs || []).length > 0
                                            ? AudioService.outputs[0].name : "No output device")
    readonly property string inputName: defaultInput
                                        ? defaultInput.name
                                        : ((AudioService.inputs || []).length > 0
                                           ? AudioService.inputs[0].name : "No input device")

    // Dense routing list: inputs first, then the outputs that are not active.
    readonly property int routingRowCount: 5
    readonly property var routingRows: routingRowList()

    // Single source of truth for "state color": seam, puck, eyebrow and glyph.
    readonly property color heroStateColor: {
        if (AudioService.errorMessage.length > 0)
            return Colors.red
        if (AudioService.outputMuted)
            return Colors.orange
        if (!root.defaultOutput && (AudioService.outputs || []).length === 0)
            return Colors.muted
        return Colors.accent
    }

    readonly property color volumeStateColor: AudioService.outputMuted ? Colors.orange : Colors.accent

    readonly property string heroStatusText: {
        if (AudioService.errorMessage.length > 0)
            return "Audio error"
        if (AudioService.outputMuted)
            return "Muted"
        if (root.defaultOutput)
            return "Live output"
        if ((AudioService.outputs || []).length > 0)
            return "Fallback output"
        return "No output"
    }

    readonly property string heroMetaText: {
        if (AudioService.errorMessage.length > 0)
            return "Last action failed"
        const outputs = AudioService.outputs || []
        if (outputs.length === 0)
            return "Connect an output device"
        const others = outputs.length - (root.defaultOutput ? 1 : 0)
        if (others <= 0)
            return root.kindText(root.defaultOutput, "Sink") + " • Only output"
        return root.kindText(root.defaultOutput, "Sink") + " • " + others
               + (others === 1 ? " other output" : " other outputs")
    }

    function deviceById(devices, deviceId) {
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].id === deviceId)
                return devices[i]
        }
        return null
    }

    function percentText(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value || 0)))) + "%"
    }

    function volumeText() {
        return percentText(AudioService.outputVolume)
    }

    function muteText() {
        return AudioService.outputMuted ? "Muted" : "Output active"
    }

    function displayName(device, fallback) {
        if (device && device.name && String(device.name).length > 0)
            return device.name
        return fallback
    }

    function kindText(device, fallback) {
        const kind = String((device && device.type) ? device.type : "").toLowerCase()
        if (kind.length === 0)
            return fallback
        return kind.charAt(0).toUpperCase() + kind.slice(1)
    }

    function deviceIcon(device, fallbackIcon) {
        const kind = String((device && device.type) ? device.type : "").toLowerCase()
        const name = String((device && device.name) ? device.name : "").toLowerCase()
        if (kind.indexOf("source") >= 0 || name.indexOf("microphone") >= 0 || name.indexOf("mic") >= 0)
            return "󰍬"
        if (name.indexOf("head") >= 0 || name.indexOf("ear") >= 0)
            return "󰋋"
        if (name.indexOf("hdmi") >= 0 || name.indexOf("display") >= 0 || name.indexOf("monitor") >= 0)
            return "󰍹"
        return fallbackIcon
    }

    function outputPercentFromX(trackWidth, clickX) {
        const usableWidth = Math.max(1, trackWidth)
        return Math.max(0, Math.min(100, Math.round((clickX / usableWidth) * 100)))
    }

    function routingRowList() {
        const items = []
        const inputs = AudioService.inputs || []
        for (let i = 0; i < inputs.length; i++) {
            if (inputs[i])
                items.push(makeRoutingRow(inputs[i], "Input"))
        }
        const outputs = AudioService.outputs || []
        for (let i = 0; i < outputs.length; i++) {
            if (outputs[i] && outputs[i].id !== AudioService.defaultOutputId)
                items.push(makeRoutingRow(outputs[i], "Output"))
        }
        return items.slice(0, root.routingRowCount)
    }

    function makeRoutingRow(device, kind) {
        const isInput = kind === "Input"
        const activeId = isInput ? AudioService.defaultInputId : AudioService.defaultOutputId
        const isDeviceMuted = !!(device && device.muted)
        return {
            rowId: String(device && device.id ? device.id : ""),
            kind: kind,
            glyphText: root.deviceIcon(device, isInput ? "󰍬" : "󰕾"),
            titleText: root.displayName(device, isInput ? "Input device" : "Output device"),
            metaText: root.kindText(device, isInput ? "Source" : "Sink")
                      + (isDeviceMuted ? " • Muted" : " • " + root.percentText(device.volume)),
            isActive: String(device && device.id ? device.id : "") === String(activeId || ""),
            isMuted: isDeviceMuted,
            levelText: root.percentText(device.volume)
        }
    }

    function selectRoutingRow(row) {
        if (!row || row.rowId.length === 0)
            return
        if (row.kind === "Input")
            AudioService.setDefaultInput(row.rowId)
        else
            AudioService.setDefaultOutput(row.rowId)
    }

    onStandaloneChanged: if (standalone) panelOpen = true
    onVisibleChanged: {
        if (!visible)
            panelOpen = false
        else if (standalone)
            panelOpen = true
    }

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingSm
        spacing: Theme.spacingSm

        // ── Layer 1 — hero: the active output device owns this block ──────
        Rectangle {
            id: heroBlock
            Layout.fillWidth: true
            implicitHeight: heroRow.implicitHeight + Theme.spacingSm * 2
            radius: Theme.radiusLg
            color: heroClickArea.containsMouse
                   ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.60)
                   : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b,
                             AudioService.outputMuted ? 0.24 : 0.44)
            border.width: 0

            // Click/hover surface sits below the content so the chevron keeps its
            // own affordance while the rest of the hero toggles the module.
            MouseArea {
                id: heroClickArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.standalone)
                        root.panelOpen = true
                    else
                        root.panelOpen = !root.panelOpen
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
                opacity: AudioService.outputMuted ? 0.75 : 0.95
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
                    id: statePuck
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
                            text: root.deviceIcon(root.defaultOutput, AudioService.outputMuted ? "󰝟" : "󰕾")
                            color: root.heroStateColor
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: AudioService.outputMuted ? "Muted" : root.volumeText()
                            color: root.heroStateColor
                            font {
                                family: Colors.uiFont
                                pixelSize: Theme.fontSizeCaption
                                weight: AudioService.outputMuted ? Font.DemiBold : Font.Normal
                            }
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
                            weight: AudioService.outputMuted ? Font.DemiBold : Font.Normal
                            capitalization: Font.AllUppercase
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.outputName
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

                Rectangle {
                    id: chevronButton
                    visible: !root.standalone
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusPill
                    color: chevronClickArea.containsMouse || root.panelOpen
                           ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
                           : "transparent"
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: root.panelOpen ? "⌃" : "⌄"
                        color: Colors.textDim
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                    }

                    MouseArea {
                        id: chevronClickArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.panelOpen = !root.panelOpen
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: AudioService.errorMessage.length > 0
            text: AudioService.errorMessage
            wrapMode: Text.WordWrap
            color: Colors.red
            font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
        }

        // ── Layer 2 — primary control: output volume, inset, no borders ───
        RowLayout {
            id: volumeGroup
            Layout.fillWidth: true
            spacing: Theme.spacingMd

            Rectangle {
                id: volumeSlab
                Layout.fillWidth: true
                implicitHeight: volumeRow.implicitHeight + Theme.spacingSm * 2
                radius: Theme.radiusMd
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.45)
                border.width: 0

                RowLayout {
                    id: volumeRow
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    spacing: Theme.spacingMd

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Theme.spacingXs

                        Text {
                            Layout.fillWidth: true
                            text: "Volume"
                            elide: Text.ElideRight
                            color: Colors.textDim
                            font {
                                family: Colors.uiFont
                                pixelSize: Theme.fontSizeCaption
                                capitalization: Font.AllUppercase
                            }
                        }

                        // Inset track; height is one doubled progress token so
                        // the primary control reads heavier than the seam.
                        Rectangle {
                            id: volumeTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.panelVolumeTrackHeight
                            radius: Theme.radiusPill
                            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.28)

                            Rectangle {
                                id: volumeFill
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                width: parent.width * Math.max(0, Math.min(100, Number(AudioService.outputVolume || 0))) / 100
                                radius: parent.radius
                                color: root.volumeStateColor
                                opacity: AudioService.outputMuted ? 0.55 : 0.90

                                Behavior on width {
                                    enabled: !volumeMouseArea.pressed
                                    NumberAnimation { duration: Theme.animFast }
                                }
                            }

                            Rectangle {
                                id: volumeKnob
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, volumeFill.width - width / 2))
                                width: Theme.panelVolumeTrackHeight
                                height: Theme.panelVolumeTrackHeight
                                radius: Theme.radiusPill
                                color: Colors.textBright
                                opacity: volumeMouseArea.containsMouse || volumeMouseArea.pressed ? 1.0 : 0.80
                            }

                            MouseArea {
                                id: volumeMouseArea
                                anchors.fill: parent
                                anchors.topMargin: -Theme.spacingXs
                                anchors.bottomMargin: -Theme.spacingXs
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => AudioService.setOutputVolume(
                                    root.outputPercentFromX(volumeTrack.width, mouse.x))
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        AudioService.setOutputVolume(
                                            root.outputPercentFromX(volumeTrack.width, mouse.x))
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.volumeText()
                            color: AudioService.outputMuted ? Colors.orange : Colors.textBright
                            font {
                                family: Colors.displayFont
                                pixelSize: Theme.fontSizeBodyLg
                                weight: AudioService.outputMuted ? Font.Normal : Font.DemiBold
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.muteText()
                            color: Colors.textDim
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                        }
                    }
                }
            }

            AudioPillAction {
                Layout.alignment: Qt.AlignVCenter
                label: AudioService.outputMuted ? "Unmute" : "Mute"
                glyph: AudioService.outputMuted ? "󰝟" : "󰕾"
                accentColor: Colors.orange
                active: AudioService.outputMuted
                onTriggered: AudioService.setOutputMuted(!AudioService.outputMuted)
            }
        }

        // ── Layer 3 — routing: secondary, denser, quieter ─────────────────
        ColumnLayout {
            id: routingGroup
            Layout.fillWidth: true
            visible: root.panelOpen
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
                    text: "Routing"
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

                Text {
                    Layout.maximumWidth: 160
                    text: "Input " + root.inputName
                    elide: Text.ElideRight
                    color: root.defaultInput ? Colors.textDim : Colors.muted
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.routingRows.length === 0
                text: "No additional devices found"
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }

            Repeater {
                model: root.routingRows

                delegate: AudioRoutingRow {
                    Layout.fillWidth: true
                    glyphText: modelData.glyphText
                    titleText: modelData.titleText
                    metaText: modelData.kind + " • " + modelData.metaText
                    trailingText: modelData.isActive
                                  ? "Active"
                                  : (modelData.isMuted ? "Muted" : modelData.levelText)
                    isActive: modelData.isActive
                    isMuted: modelData.isMuted
                    onRowSelected: root.selectRoutingRow(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingXs
                visible: root.routingRows.length >= root.routingRowCount
                text: "More devices are listed in the panel below"
                color: Colors.muted
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
            }
        }

        // Keep audio detail as an attached secondary surface instead of a
        // separate PanelWindow to avoid changing global overlay coordination.
        AudioControlPanel {
            Layout.fillWidth: true
            visible: root.panelOpen
            onCloseRequested: root.panelOpen = false
        }
    }

    // Secondary routing row: dense, quiet, tint only on hover/active.
    component AudioRoutingRow: Rectangle {
        id: routingRow

        property string glyphText: "󰕾"
        property string titleText: "Device"
        property string metaText: ""
        property string trailingText: ""
        property bool isActive: false
        property bool isMuted: false

        signal rowSelected()

        Layout.fillWidth: true
        implicitHeight: rowContent.implicitHeight + Theme.spacingXs * 2
        radius: Theme.radiusMd
        color: routingRow.isActive
               ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
               : (routingRowClickArea.containsMouse
                  ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.40)
                  : "transparent")
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
                text: routingRow.glyphText
                color: routingRow.isActive ? Colors.accent : Colors.muted
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: routingRow.titleText
                    elide: Text.ElideRight
                    color: routingRow.isActive ? Colors.textBright : Colors.text
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel; weight: Font.DemiBold }
                }

                Text {
                    Layout.fillWidth: true
                    visible: routingRow.metaText.length > 0
                    text: routingRow.metaText
                    elide: Text.ElideRight
                    color: Colors.textDim
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: routingRow.trailingText
                color: routingRow.isActive
                       ? Colors.accent
                       : (routingRow.isMuted ? Colors.orange : Colors.textDim)
                font {
                    family: Colors.uiFont
                    pixelSize: Theme.fontSizeCaption
                    weight: routingRow.isActive || routingRow.isMuted ? Font.DemiBold : Font.Normal
                }
            }
        }

        MouseArea {
            id: routingRowClickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: routingRow.rowSelected()
        }
    }

    // Borderless tinted pill: mute is the only always-visible action affordance.
    component AudioPillAction: Rectangle {
        id: pillAction

        property string label: ""
        property string glyph: ""
        property color accentColor: Colors.accent
        property bool active: false

        signal triggered()

        implicitWidth: pillRow.implicitWidth + Theme.spacingMd
        implicitHeight: 26
        radius: Theme.radiusPill
        opacity: enabled ? 1.0 : 0.55
        color: pillClickArea.containsMouse || pillAction.active
               ? Qt.rgba(pillAction.accentColor.r, pillAction.accentColor.g, pillAction.accentColor.b,
                         pillAction.active ? 0.28 : 0.24)
               : Qt.rgba(pillAction.accentColor.r, pillAction.accentColor.g, pillAction.accentColor.b, 0.14)
        border.width: 0

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spacingXs

            Text {
                visible: pillAction.glyph.length > 0
                text: pillAction.glyph
                color: Colors.text
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeLabel }
            }

            Text {
                text: pillAction.label
                color: pillAction.active ? pillAction.accentColor : Colors.text
                font {
                    family: Colors.uiFont
                    pixelSize: Theme.fontSizeLabel
                    weight: pillAction.active ? Font.DemiBold : Font.Normal
                }
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
