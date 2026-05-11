import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 37 + 11; right: 11 }

    implicitWidth: 380
    implicitHeight: toastColumn.implicitHeight

    property bool soundMuted: false

    // Internal model: { id, summary, body, appName, urgency, actions, notif }
    ListModel { id: toastModel }

    Process {
        id: soundPlayer
        command: ["paplay", ""]
        running: false
    }

    function playSound(urgency) {
        if (root.soundMuted) return
        const base = "/usr/share/sounds/freedesktop/stereo/"
        if (urgency === NotificationUrgency.Critical)
            soundPlayer.command = ["paplay", base + "dialog-error.oga"]
        else if (urgency === NotificationUrgency.Low)
            soundPlayer.command = ["paplay", base + "message-new-instant.oga"]
        else
            soundPlayer.command = ["paplay", base + "dialog-information.oga"]
        soundPlayer.running = true
    }

    NotificationServer {
        id: server
        keepOnReload: true

        onNotification: notif => {
            for (let i = 0; i < toastModel.count; i++) {
                if (toastModel.get(i).notifId === notif.id) {
                    toastModel.remove(i)
                    break
                }
            }

            const timeout = notif.expireTimeout > 0 ? notif.expireTimeout : 5000

            toastModel.append({
                notifId:  notif.id,
                summary:  notif.summary,
                body:     notif.body,
                appName:  notif.appName,
                urgency:  notif.urgency,
                timeout:  timeout,
                notif:    notif
            })

            root.playSound(notif.urgency)
        }
    }

    ColumnLayout {
        id: toastColumn
        width: parent.width
        spacing: 8

        Repeater {
            model: toastModel

            delegate: NotificationToast {
                required property var model
                required property int index

                Layout.fillWidth: true

                summary:  model.summary
                body:     model.body
                appName:  model.appName
                urgency:  model.urgency
                timeout:  model.timeout
                notif:    model.notif

                onDismissed: toastModel.remove(index)
            }
        }
    }
}
