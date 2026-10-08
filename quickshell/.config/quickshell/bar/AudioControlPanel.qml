import QtQuick
import QtQuick.Layouts
import "../services"
import "../theme"

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: panelColumn.implicitHeight + Theme.spacingSm * 2
    radius: Theme.radiusLg
    color: "transparent"
    border.width: 0

    property bool outputExpanded: false
    property bool inputExpanded: false

    function activeDevice(devices, deviceId) {
        const items = devices || []
        for (let i = 0; i < items.length; i++) {
            if (items[i] && items[i].id === deviceId)
                return items[i]
        }
        return null
    }

    function displayName(device, fallback) {
        if (device && device.name && String(device.name).length > 0)
            return device.name
        return fallback
    }

    function deviceIcon(device, fallbackIcon) {
        const type = String((device && device.type) ? device.type : "").toLowerCase()
        const name = String((device && device.name) ? device.name : "").toLowerCase()
        if (type.indexOf("source") >= 0 || name.indexOf("microphone") >= 0 || name.indexOf("mic") >= 0)
            return "󰍬"
        if (name.indexOf("head") >= 0 || name.indexOf("ear") >= 0)
            return "󰋋"
        if (name.indexOf("hdmi") >= 0 || name.indexOf("display") >= 0 || name.indexOf("monitor") >= 0)
            return "󰍹"
        return fallbackIcon
    }

    function percentText(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value || 0)))) + "%"
    }

    ColumnLayout {
        id: panelColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingSm
        spacing: Theme.spacingMd

        AudioBlock {
            Layout.fillWidth: true
            visible: root.outputExpanded
            title: "Output"
            iconText: "󰕾"
            devices: AudioService.outputs || []
            activeId: AudioService.defaultOutputId
            level: AudioService.outputVolume
            muted: AudioService.outputMuted
            emptyText: "No output devices found"
            controlLabel: "Volume"
            fallbackDeviceName: "Output device"
            fallbackIcon: "󰕾"
            onDeviceSelected: deviceId => AudioService.setDefaultOutput(deviceId)
            onLevelCommitted: value => AudioService.setOutputVolume(value)
            onMuteChanged: mutedValue => AudioService.setOutputMuted(mutedValue)
        }

        AudioBlock {
            Layout.fillWidth: true
            visible: root.inputExpanded
            title: "Input"
            iconText: "󰍬"
            devices: AudioService.inputs || []
            activeId: AudioService.defaultInputId
            level: AudioService.inputVolume
            muted: AudioService.inputMuted
            emptyText: "No input devices found"
            controlLabel: "Gain"
            fallbackDeviceName: "Input device"
            fallbackIcon: "󰍬"
            onDeviceSelected: deviceId => AudioService.setDefaultInput(deviceId)
            onLevelCommitted: value => AudioService.setInputVolume(value)
            onMuteChanged: mutedValue => AudioService.setInputMuted(mutedValue)
        }
    }

    component AudioBlock: Rectangle {
        id: block

        property string title: ""
        property string iconText: ""
        property var devices: []
        property string activeId: ""
        property int level: 0
        property bool muted: false
        property string emptyText: ""
        property string controlLabel: "Level"
        property string fallbackDeviceName: "Device"
        property string fallbackIcon: "󰕾"
        property bool showHeader: false
        property bool showLevel: false

        signal deviceSelected(string deviceId)
        signal levelCommitted(int value)
        signal muteChanged(bool mutedValue)

        implicitHeight: blockColumn.implicitHeight + Theme.spacingMd * 2
        radius: Theme.radiusMd
        color: Theme.surfaceCard(Colors.base01)
        border.width: 0

        ColumnLayout {
            id: blockColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingSm
            spacing: Theme.spacingSm

            RowLayout {
                visible: block.showHeader
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Text {
                    text: block.iconText
                    color: block.muted ? Colors.orange : Colors.accent
                    font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                }

                Text {
                    Layout.fillWidth: true
                    text: block.title
                    color: Colors.text
                    font { family: Colors.displayFont; pixelSize: Theme.fontSizeBodyLg }
                }

                Text {
                    text: block.muted ? "Muted" : root.percentText(block.level)
                    color: block.muted ? Colors.orange : Colors.green
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                }
            }

            LevelControl {
                visible: block.showLevel
                Layout.fillWidth: true
                label: block.controlLabel
                value: block.level
                muted: block.muted
                onValueCommitted: value => block.levelCommitted(value)
                onMuteRequested: block.muteChanged(!block.muted)
            }

            Text {
                Layout.fillWidth: true
                visible: (block.devices || []).length === 0
                text: block.emptyText
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
            }

            Repeater {
                model: block.devices || []

                delegate: DeviceRow {
                    Layout.fillWidth: true
                    device: modelData
                    active: modelData && modelData.id === block.activeId
                    nameText: root.displayName(modelData, block.fallbackDeviceName)
                    iconText: root.deviceIcon(modelData, block.fallbackIcon)
                    levelText: root.percentText(modelData ? modelData.volume : 0)
                    muted: modelData ? !!modelData.muted : false
                    onSelected: deviceId => block.deviceSelected(deviceId)
                }
            }
        }
    }

    component LevelControl: Rectangle {
        id: control

        property string label: "Level"
        property int value: 0
        property bool muted: false

        signal valueCommitted(int value)
        signal muteRequested()

        implicitHeight: 44
        radius: Theme.radiusMd
        color: Theme.surfaceNested(Colors.base02)
        border.width: 0

        function valueFromX(x) {
            const usableWidth = Math.max(1, track.width)
            return Math.max(0, Math.min(100, Math.round((x / usableWidth) * 100)))
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingSm
            spacing: Theme.spacingSm

            Text {
                text: control.label
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 8
                radius: Theme.dashboardProgressRadius
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.28)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(100, control.value)) / 100
                    radius: parent.radius
                    color: control.muted ? Colors.orange : Colors.accent
                    opacity: control.muted ? 0.55 : 0.85
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => control.valueCommitted(control.valueFromX(mouse.x))
                    onPositionChanged: mouse => {
                        if (pressed)
                            control.valueCommitted(control.valueFromX(mouse.x))
                    }
                }
            }

            Text {
                text: root.percentText(control.value)
                color: Colors.text
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }

            Rectangle {
                Layout.preferredWidth: 34
                implicitHeight: 26
                radius: Theme.radiusMd
                color: control.muted
                       ? Theme.buttonFill(Colors.orange, true, muteArea.pressed ? "pressed" : (muteArea.containsMouse ? "hover" : "rest"))
                       : (muteArea.containsMouse ? Theme.buttonFill(Colors.muted, false, "hover") : "transparent")
                border.width: 0

                Text {
                    anchors.centerIn: parent
                    text: control.muted ? "󰝟" : "󰕾"
                    color: control.muted ? Colors.orange : Colors.textDim
                    font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
                }

                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: control.muteRequested()
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row

        property var device: null
        property bool active: false
        property string nameText: "Device"
        property string iconText: "󰕾"
        property string levelText: "0%"
        property bool muted: false

        signal selected(string deviceId)

        implicitHeight: 42
        radius: Theme.radiusMd
        color: row.active
               ? Theme.buttonFill(Colors.accent, true, rowArea.pressed ? "pressed" : "rest")
               : rowArea.containsMouse
                 ? Theme.buttonFill(Colors.accent, false, "hover")
                 : "transparent"
        border.width: 0

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingSm
            spacing: Theme.spacingSm

            Text {
                text: row.iconText
                color: row.active ? Colors.green : Colors.accent
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: row.nameText
                    elide: Text.ElideRight
                    color: Colors.text
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                }

                Text {
                    Layout.fillWidth: true
                    text: (row.active ? "Default" : "Available") + (row.device && row.device.type ? (" • " + row.device.type) : "")
                    elide: Text.ElideRight
                    color: Colors.textDim
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                }
            }

            Text {
                text: row.muted ? "Muted" : row.levelText
                color: row.muted ? Colors.orange : Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }

            Text {
                visible: row.active
                text: "✓"
                color: Colors.green
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel; weight: Font.DemiBold }
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.device && row.device.id)
                    row.selected(row.device.id)
            }
        }
    }
}
