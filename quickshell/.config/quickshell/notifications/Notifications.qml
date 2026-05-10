import QtQuick
import QtQuick.Layouts
import Quickshell
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

    // Internal model: { id, summary, body, appName, urgency, actions, notif }
    ListModel { id: toastModel }

    NotificationServer {
        id: server
        keepOnReload: true

        onNotification: notif => {
            // Replace existing toast from same app+summary, otherwise append
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
