import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../theme"

Item {
    id: root

    property var mediaPlayer
    property QtObject systemStatsState: null
    property int currentTab: 0

    readonly property int railWidth: Theme.dashboardRailWidth
    readonly property int tabHeight: 40
    readonly property int tabSpacing: Theme.spacingSm

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingMd

        Item {
            Layout.preferredWidth: root.railWidth
            Layout.fillHeight: true

            Rectangle {
                width: parent.width
                height: root.tabHeight
                y: root.currentTab * (root.tabHeight + root.tabSpacing)
                radius: Theme.radiusMd
                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, Theme.opacityDim)

                Behavior on y {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
                }
            }

            Column {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.tabSpacing

                Repeater {
                    model: [
                        { "icon": "󰎆", "label": "Media" },
                        { "icon": "󰚆", "label": "Metrics" }
                    ]

                    delegate: Item {
                        width: root.railWidth
                        height: root.tabHeight

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: root.currentTab === index ? Colors.accent : Colors.textDim
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => {
                                root.currentTab = index
                                mouse.accepted = true
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: mediaPane
                anchors.fill: parent
                visible: root.currentTab === 0
                opacity: root.currentTab === 0 ? 1 : 0
                transform: Translate {
                    id: mediaPaneTranslate
                    x: root.currentTab === 0 ? 0 : -Theme.spacingMd

                    Behavior on x {
                        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: mouse => mouse.accepted = true
                }

                ColumnLayout {
                    z: 1
                    anchors.fill: parent
                    spacing: Theme.spacingMd

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Text {
                            text: "󰎆"
                            color: Colors.accent
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Media"
                            color: Colors.text
                            font { family: Colors.displayFont; pixelSize: Theme.fontSizeBodyLg }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.mediaPlayer?.trackTitle || "No media playing"
                            color: Colors.text
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                            elide: Text.ElideRight
                            horizontalAlignment: root.mediaPlayer ? Text.AlignLeft : Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.mediaPlayer !== null
                            text: root.mediaPlayer?.trackArtist ?? ""
                            color: Colors.textDim
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 3
                        radius: 2
                        visible: root.mediaPlayer !== null
                        color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)

                        Rectangle {
                            width: {
                                const len = root.mediaPlayer?.length ?? 0
                                const pos = root.mediaPlayer?.position ?? 0
                                return len > 0 ? parent.width * Math.min(1, Math.max(0, pos / len)) : 0
                            }
                            height: parent.height
                            radius: parent.radius
                            color: Colors.accent

                            Behavior on width {
                                NumberAnimation { duration: Theme.animSlow }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.mediaPlayer !== null
                        spacing: Theme.spacingXl

                        Text {
                            text: "󰒮"
                            color: Colors.textDim
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: mouse => {
                                    root.mediaPlayer?.previous()
                                    mouse.accepted = true
                                }
                            }
                        }

                        Text {
                            text: root.mediaPlayer?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                            color: Colors.accent
                            font { family: Colors.monoFont; pixelSize: 22 }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: mouse => {
                                    root.mediaPlayer?.togglePlaying()
                                    mouse.accepted = true
                                }
                            }
                        }

                        Text {
                            text: "󰒭"
                            color: Colors.textDim
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: mouse => {
                                    root.mediaPlayer?.next()
                                    mouse.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: metricsPane
                anchors.fill: parent
                visible: root.currentTab === 1
                opacity: root.currentTab === 1 ? 1 : 0
                transform: Translate {
                    id: metricsPaneTranslate
                    x: root.currentTab === 1 ? 0 : Theme.spacingMd

                    Behavior on x {
                        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: mouse => mouse.accepted = true
                }

                MetricsPane {
                    z: 1
                    anchors.fill: parent
                    systemStatsState: root.systemStatsState
                }
            }
        }
    }
}
