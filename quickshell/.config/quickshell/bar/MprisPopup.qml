import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../theme"

Item {
    id: root

    property real anchorX: 0

    signal closed()

    function open()   { popup.visible = true }
    function close()  { popup.visible = false; closed() }
    function toggle() { popup.visible ? root.close() : root.open() }
    readonly property bool isOpen: popup.visible

    readonly property var player: {
        const players = Mpris.players.values
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    PanelWindow {
        id: popup
        visible: false
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            readonly property int popupW: 280
            readonly property int popupH: (root.player?.trackArtUrl ?? "") !== "" ? 320 : 220

            width: popupW
            height: popupH
            x: Math.min(Math.max(root.anchorX - popupW / 2, 8), popup.width - popupW - 8)
            y: 44

            radius: Theme.radiusMd
            color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacitySurface)
            border {
                width: 1
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.25)
            }

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors { fill: parent; margins: Theme.spacingLg }
                spacing: Theme.spacingMd

                // Cover art
                Rectangle {
                    Layout.fillWidth: true
                    height: 120
                    radius: Theme.radiusSm
                    color: Qt.rgba(Colors.base00.r, Colors.base00.g, Colors.base00.b, 0.8)
                    visible: (root.player?.trackArtUrl ?? "") !== ""
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                // Title + artist
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackTitle ?? ""
                        color: Colors.text
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackArtist ?? ""
                        color: Colors.textDim
                        font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                        elide: Text.ElideRight
                    }
                }

                // Progress bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    radius: 2
                    color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)

                    Rectangle {
                        width: {
                            const len = root.player?.length ?? 0
                            const pos = root.player?.position ?? 0
                            return len > 0 ? parent.width * (pos / len) : 0
                        }
                        height: parent.height
                        radius: parent.radius
                        color: Colors.accent

                        Behavior on width {
                            NumberAnimation { duration: Theme.animSlow }
                        }
                    }
                }

                // Controls
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.spacingXl

                    Text {
                        text: "󰒮"
                        color: Colors.textDim
                        font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.player?.previous()
                        }
                    }

                    Text {
                        text: root.player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                        color: Colors.accent
                        font { family: Colors.monoFont; pixelSize: 22 }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.player?.togglePlaying()
                        }
                    }

                    Text {
                        text: "󰒭"
                        color: Colors.textDim
                        font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.player?.next()
                        }
                    }
                }
            }
        }
    }
}
