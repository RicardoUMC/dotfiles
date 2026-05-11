import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../theme"

Item {
    id: root

    property string summary: ""
    property string body: ""
    property string appName: ""
    property int    urgency: NotificationUrgency.Normal
    property int    timeout: 5000
    property var    notif: null

    signal dismissed()

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Auto-dismiss timer — pauses on hover
    Timer {
        id: dismissTimer
        interval: root.timeout
        running: true
        repeat: false
        onTriggered: root.dismissed()
    }

    // Progress bar width binding
    readonly property real progress: dismissTimer.running
        ? 1.0 - (dismissTimer.interval > 0 ? dismissTimer.interval / root.timeout : 1.0)
        : 1.0

    // Urgency-based accent color
    readonly property color urgencyColor: {
        if (urgency === NotificationUrgency.Critical) return Colors.red
        if (urgency === NotificationUrgency.Low)      return Colors.muted
        return Colors.accent
    }

    Rectangle {
        id: card
        width: root.width
        implicitHeight: content.implicitHeight + Theme.spacingMd * 2
        radius: Theme.radiusMd
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacitySurface)
        border {
            width: 1
            color: Qt.rgba(root.urgencyColor.r, root.urgencyColor.g, root.urgencyColor.b, 0.5)
        }

        // Timeout progress bar at the bottom of the card
        Rectangle {
            id: progressBar
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 2
            radius: 1
            color: "transparent"

            Rectangle {
                width: progressBar.width * (1.0 - dismissTimer.interval / root.timeout)
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(root.urgencyColor.r, root.urgencyColor.g, root.urgencyColor.b, 0.6)

                Behavior on width { SmoothedAnimation { velocity: progressBar.width / (root.timeout / 1000) } }
            }
        }

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingMd }
            anchors.bottomMargin: Theme.spacingMd
            spacing: Theme.spacingXs

            // Header: app name + close button
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm - 2

                Text {
                    text: root.appName
                    color: Colors.muted
                    font { family: Colors.monoFont; pixelSize: Theme.fontSizeCaption }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "✕"
                    color: Colors.muted
                    font { family: Colors.monoFont; pixelSize: Theme.fontSizeCaption }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.notif) root.notif.dismiss()
                            root.dismissed()
                        }
                    }
                }
            }

            // Summary
            Text {
                text: root.summary
                color: Colors.text
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody; bold: true }
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: root.summary.length > 0
            }

            // Body
            Text {
                text: root.body
                color: Colors.textDim
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody - 1 }
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: root.body.length > 0
            }

            // Actions
            RowLayout {
                spacing: Theme.spacingSm - 2
                Layout.fillWidth: true
                visible: root.notif !== null && root.notif.actions.length > 0

                Repeater {
                    model: root.notif ? root.notif.actions : []

                    delegate: Rectangle {
                        required property var modelData

                        implicitHeight: 26
                        implicitWidth: actionLabel.implicitWidth + 20
                        radius: Theme.radiusSm
                        color: actionMa.containsMouse
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                            : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
                        border {
                            width: 1
                            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                        }

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Colors.text
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeLabel }
                        }

                        MouseArea {
                            id: actionMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                modelData.invoke()
                                root.dismissed()
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            // Pause timer on hover, resume on leave
            onEntered: dismissTimer.running = false
            onExited:  dismissTimer.running = true
            // Propagate clicks to children (actions, close button)
            propagateComposedEvents: true
            onClicked: mouse => mouse.accepted = false
        }
    }

    // Slide-in animation on appear
    NumberAnimation on opacity {
        from: 0; to: 1
        duration: Theme.animNormal
        easing.type: Easing.OutCubic
    }
}
