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
    readonly property string outputName: defaultOutput
                                         ? defaultOutput.name
                                         : ((AudioService.outputs || []).length > 0
                                            ? AudioService.outputs[0].name : "No output device")

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
            visible: !root.panelOpen
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

        // Compact state: keep the two directly actionable levels together.
        CompactLevelControl {
            visible: !root.panelOpen
            Layout.fillWidth: true
            label: "Output"
            glyph: "󰕾"
            value: AudioService.outputVolume
            muted: AudioService.outputMuted
            accentColor: root.volumeStateColor
            onValueCommitted: value => AudioService.setOutputVolume(value)
            onMuteRequested: AudioService.setOutputMuted(!AudioService.outputMuted)
        }

        CompactLevelControl {
            visible: !root.panelOpen
            Layout.fillWidth: true
            label: "Microphone"
            glyph: "󰍬"
            value: AudioService.inputVolume
            muted: AudioService.inputMuted
            accentColor: AudioService.inputMuted ? Colors.orange : Colors.accent
            onValueCommitted: value => AudioService.setInputVolume(value)
            onMuteRequested: AudioService.setInputMuted(!AudioService.inputMuted)
        }

        // Keep audio detail as an attached secondary surface instead of a
        // separate PanelWindow to avoid changing global overlay coordination.
        AudioControlPanel {
            Layout.fillWidth: true
            visible: root.panelOpen
            onCloseRequested: root.panelOpen = false
        }
    }

    component CompactLevelControl: Rectangle {
        id: compactControl

        property string label: "Level"
        property string glyph: "󰕾"
        property int value: 0
        property bool muted: false
        property color accentColor: Colors.accent

        signal valueCommitted(int value)
        signal muteRequested()

        implicitHeight: compactColumn.implicitHeight + Theme.spacingSm * 2
        radius: Theme.radiusMd
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.45)
        border.width: 0

        function valueFromX(clickX) {
            return Math.max(0, Math.min(100,
                Math.round((clickX / Math.max(1, compactTrack.width)) * 100)))
        }

        function percentText(value) {
            return Math.max(0, Math.min(100, Math.round(Number(value || 0)))) + "%"
        }

        ColumnLayout {
            id: compactColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingSm
            spacing: Theme.spacingXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Text {
                    text: compactControl.glyph
                    color: compactControl.muted ? Colors.orange : compactControl.accentColor
                    font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
                }

                Text {
                    Layout.fillWidth: true
                    text: compactControl.label
                    color: Colors.textDim
                    font {
                        family: Colors.uiFont
                        pixelSize: Theme.fontSizeCaption
                        capitalization: Font.AllUppercase
                    }
                }

                Text {
                    text: compactControl.percentText(compactControl.value)
                    color: compactControl.muted ? Colors.orange : Colors.textBright
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel; weight: Font.DemiBold }
                }

                Rectangle {
                    id: compactMuteButton
                    Layout.preferredWidth: compactMuteLabel.implicitWidth + Theme.spacingMd
                    Layout.preferredHeight: 26
                    radius: Theme.radiusPill
                    color: compactMuteArea.containsMouse || compactControl.muted
                           ? Qt.rgba(Colors.orange.r, Colors.orange.g, Colors.orange.b,
                                     compactControl.muted ? 0.28 : 0.24)
                           : Qt.rgba(Colors.orange.r, Colors.orange.g, Colors.orange.b, 0.14)
                    border.width: 0

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXs

                        Text {
                            text: compactControl.muted ? "󰝟" : "󰕾"
                            color: Colors.text
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeLabel }
                        }

                        Text {
                            id: compactMuteLabel
                            text: compactControl.muted ? "Unmute" : "Mute"
                            color: compactControl.muted ? Colors.orange : Colors.text
                            font {
                                family: Colors.uiFont
                                pixelSize: Theme.fontSizeLabel
                                weight: compactControl.muted ? Font.DemiBold : Font.Normal
                            }
                        }
                    }

                    MouseArea {
                        id: compactMuteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: compactControl.muteRequested()
                    }
                }
            }

            Rectangle {
                id: compactTrack
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.panelVolumeTrackHeight
                radius: Theme.radiusPill
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.28)

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: parent.width * Math.max(0, Math.min(100, compactControl.value)) / 100
                    radius: parent.radius
                    color: compactControl.muted ? Colors.orange : compactControl.accentColor
                    opacity: compactControl.muted ? 0.55 : 0.90
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -Theme.spacingXs
                    anchors.bottomMargin: -Theme.spacingXs
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => compactControl.valueCommitted(compactControl.valueFromX(mouse.x))
                    onPositionChanged: mouse => {
                        if (pressed)
                            compactControl.valueCommitted(compactControl.valueFromX(mouse.x))
                    }
                }
            }
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
