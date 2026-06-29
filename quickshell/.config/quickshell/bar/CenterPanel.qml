import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../theme"

// Floating overlay panel anchored below the bar center.
// Follows the same pattern as PowerMenu.qml / MprisPopup.qml:
// an Item wrapping a fullscreen PanelWindow (WlrLayer.Overlay, ExclusionMode.Ignore).
Item {
    id: root

    signal opened()
    signal closed()

    function open()  { popup.visible = true;  opened() }
    function close() { popup.visible = false; closed() }

    readonly property bool isOpen: popup.visible

    PanelWindow {
        id: popup
        visible: false
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: if (visible) keyHandler.forceActiveFocus()

        // Fullscreen dismiss area — click anywhere outside the content closes the panel
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        // Keyboard handler — Escape closes the panel
        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }
        }

        // Content rectangle anchored centered below the bar rail
        Rectangle {
            id: content
            width: 380
            height: 180
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.barHeight + Theme.spacingSm

            radius: Theme.radiusMd
            color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.islandBgOpacity)
            border {
                width: 1
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.islandBorderOpacity)
            }

            // Accent left-border — 2px Colors.accent spanning full height
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 2
                color: Colors.accent
                radius: 1
            }

            // Consume clicks inside the content so they don't propagate to the dismiss MouseArea
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: col
                anchors { fill: parent; margins: Theme.spacingMd }
                spacing: Theme.spacingSm

                // Expanded ClockChip — always shows date line
                ClockChip {
                    Layout.fillWidth: true
                    expanded: true
                }

                // MPRIS mini-player section
                Item {
                    id: mprisSection
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mprisPlayer !== null

                    readonly property var mprisPlayer: {
                        const players = Mpris.players.values
                        for (let i = 0; i < players.length; i++) {
                            if (players[i].playbackState === MprisPlaybackState.Playing)
                                return players[i]
                        }
                        return players.length > 0 ? players[0] : null
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: mprisSection.mprisPlayer?.trackTitle ?? ""
                            color: Colors.text
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: mprisSection.mprisPlayer?.trackArtist ?? ""
                            color: Colors.textDim
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            maximumLineCount: 1
                        }

                        // Progress bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 3
                            radius: 2
                            Layout.topMargin: 4
                            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)

                            Rectangle {
                                width: {
                                    const len = mprisSection.mprisPlayer?.length ?? 0
                                    const pos = mprisSection.mprisPlayer?.position ?? 0
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

                        // Mini transport controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacingMd
                            Layout.topMargin: 4

                            Text {
                                text: "󰒮"
                                color: Colors.textDim
                                font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mprisSection.mprisPlayer?.previous()
                                }
                            }

                            Text {
                                text: mprisSection.mprisPlayer?.playbackState === MprisPlaybackState.Playing
                                    ? "󰏤" : "󰐊"
                                color: Colors.accent
                                font { family: Colors.monoFont; pixelSize: 22 }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mprisSection.mprisPlayer?.togglePlaying()
                                }
                            }

                            Text {
                                text: "󰒭"
                                color: Colors.textDim
                                font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mprisSection.mprisPlayer?.next()
                                }
                            }
                        }
                    }
                }

                // No-media placeholder — shown when no MPRIS player is active
                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: mprisSection.mprisPlayer === null
                    text: "No media playing"
                    color: Colors.muted
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Debug visual bounds overlay (development scaffolding)
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: parent.radius
                border {
                    width: Theme.debugBorderWidth
                    color: Theme.debugBorderColor
                }
                visible: Theme.debugVisualBounds
                z: 999
            }
        }
    }
}
