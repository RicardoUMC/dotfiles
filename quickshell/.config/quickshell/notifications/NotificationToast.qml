import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../theme"

Item {
    id: root

    // The toast surface sizes its height from this item, so the delegate needs
    // the card's measured height to propagate; without it the surface collapses
    // to 1px and the toast renders invisibly.
    implicitHeight: card.implicitHeight

    property string summary: ""
    property string body: ""
    property string appName: ""
    property int    urgency: NotificationUrgency.Normal
    property int    timeout: 5000
    property var    notif: null

    // `dismissed` is a user-initiated dismissal (close button or action);
    // `timedOut` is the countdown running out. The caller keeps history for the
    // latter and drops it for the former.
    signal dismissed()
    signal timedOut()

    // A user-resolved toast freezes its countdown immediately, before the caller
    // removes this delegate, so no tick can fire in between.
    onDismissed: root.stopClock()

    // Countdown state, measured against wall-clock time instead of a Timer
    // interval. `remainingMs` is only ever reduced by time actually spent, so
    // pausing on hover and resuming on exit continues the remainder rather than
    // restarting the full timeout.
    property int remainingMs: root.timeout
    property real clockAnchor: Date.now()
    property bool clockPaused: false
    property bool clockFinished: false

    // Fraction of the timeout still to come; drives the depletion bar below.
    property real remainingFraction: 1.0

    // Time consumed since the current anchor. Clamped to the remainder so a
    // backward or forward wall-clock adjustment can never manufacture negative
    // time or skip past more than was left.
    function elapsedSinceAnchor() {
        return Math.max(0, Math.min(root.remainingMs, Date.now() - root.clockAnchor))
    }

    function pauseClock() {
        if (root.clockPaused || root.clockFinished)
            return
        root.remainingMs = root.remainingMs - root.elapsedSinceAnchor()
        root.clockPaused = true
    }

    function resumeClock() {
        if (!root.clockPaused || root.clockFinished)
            return
        root.clockAnchor = Date.now()
        root.clockPaused = false
    }

    function stopClock() {
        root.clockFinished = true
        root.clockPaused = false
    }

    // Urgency-based accent color
    readonly property color urgencyColor: {
        if (urgency === NotificationUrgency.Critical) return Colors.red
        if (urgency === NotificationUrgency.Low)      return Colors.muted
        return Colors.accent
    }

    // Countdown tick. Deliberately a repeating short-interval Timer rather than a
    // FrameAnimation: this surface is a zero-height Overlay panel whose delegates are
    // hidden whenever DND is on, and a frame-driven clock only advances while the
    // scene graph renders. A Timer keeps suppressed toasts retiring on schedule so
    // hidden delegates cannot pile up. Accuracy comes from measuring wall-clock
    // elapsed time below, not from trusting the tick period.
    readonly property int clockTickInterval: 100

    Timer {
        id: dismissClock

        interval: root.clockTickInterval
        repeat: true
        running: !root.clockPaused && !root.clockFinished && root.timeout > 0

        onTriggered: {
            if (root.timeout <= 0)
                return
            const remaining = root.remainingMs - root.elapsedSinceAnchor()
            if (remaining <= 0) {
                root.remainingFraction = 0
                root.stopClock()
                root.timedOut()
            } else {
                root.remainingFraction = Math.min(1, remaining / root.timeout)
            }
        }
    }

    Rectangle {
        id: card
        width: root.width
        implicitHeight: content.implicitHeight + Theme.spacingMd * 2
        radius: Theme.radiusMd
        color: Theme.surfaceColor(Colors.base01, Theme.surfaceOverlayOpacity)
        border {
            width: 1
            color: Qt.rgba(root.urgencyColor.r, root.urgencyColor.g, root.urgencyColor.b, 0.5)
        }

        // Timeout progress bar at the bottom of the card: full on arrival,
        // depleting in step with the remaining time, frozen while hovered.
        Rectangle {
            id: progressBar
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 2
            radius: 1
            color: "transparent"

            Rectangle {
                width: progressBar.width * root.remainingFraction
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(root.urgencyColor.r, root.urgencyColor.g, root.urgencyColor.b, 0.6)

                // Interpolates between measured ticks so the depletion reads
                // as continuous motion.
                Behavior on width { NumberAnimation { duration: root.clockTickInterval; easing.type: Easing.Linear } }
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
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "✕"
                    color: Colors.muted
                    font { family: Colors.monoFont; pixelSize: Theme.fontSizeCaption }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.dismissed()
                    }
                }
            }

            // Summary
            Text {
                text: root.summary
                color: Colors.text
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody; bold: true }
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: root.summary.length > 0
            }

            // Body
            Text {
                text: root.body
                color: Colors.textDim
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody - 1 }
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
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
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
            // Freeze the countdown while hovered, then resume its remainder.
            onEntered: root.pauseClock()
            onExited: root.resumeClock()
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
