import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"

PanelWindow {
    id: root
    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 80
    margins {
        bottom: 60
        left: 0
        right: 0
    }

    // --- State ---
    property int  volPct: 0
    property bool muted:  false

    readonly property string icon: muted
        ? "\uf6a9"
        : (volPct === 0 ? "\udb80\udf76" : (volPct < 50 ? "\udb80\udf77" : "\udb80\udf78"))

    // --- IPC handler ---
    IpcHandler {
        target: "osd"
        function showVolume() {
            volumeReader.running = true
            root.show()
        }
    }

    // --- Read current volume after trigger ---
    Process {
        id: volumeReader
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const m = data.trim().match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (!m) return
                root.volPct = Math.round(parseFloat(m[1]) * 100)
                root.muted  = !!m[2]
                volumeReader.running = false
            }
        }
    }

    // --- Auto-dismiss ---
    Timer {
        id: dismissTimer
        interval: 2500
        repeat: false
        onTriggered: root.visible = false
    }

    function show() {
        visible = true
        dismissTimer.restart()
    }

    // --- Visual ---
    Item {
        anchors.centerIn: parent
        implicitWidth:  220
        implicitHeight: 52

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusPill
            color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, 0.92)
            border {
                width: 1
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
            }
        }

        Row {
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: Theme.spacingLg
                right: parent.right
                rightMargin: Theme.spacingLg
            }
            spacing: Theme.spacingMd

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: root.muted ? Colors.muted : Colors.blue
                font {
                    family: Colors.monoFont
                    pixelSize: Theme.fontSizeIcon
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Rectangle {
                    width: 140
                    height: 4
                    radius: Theme.radiusPill
                    color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.3)

                    Rectangle {
                        width: parent.width * (root.volPct / 100)
                        height: parent.height
                        radius: parent.radius
                        color: root.muted ? Colors.muted : Colors.blue
                        opacity: root.muted ? 0.35 : 1.0
                    }
                }

                Text {
                    text: root.muted ? "MUTED" : (root.volPct + "%")
                    color: root.muted ? Colors.muted : Colors.textDim
                    font {
                        family: Colors.uiFont
                        pixelSize: Theme.fontSizeLabel
                    }
                }
            }
        }
    }
}
