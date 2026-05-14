import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "bar"
import "launcher"
import "notifications"
import "osd"
import "theme"

ShellRoot {
    IpcHandler {
        target: "launcher"
        function toggle() { overlayManager.open("launcher") }
    }

    IpcHandler {
        target: "powermenu"
        function toggle() { overlayManager.open("powermenu") }
    }

    IpcHandler {
        target: "notifications"
        function toggleSound() {
            notifications.soundMuted = !notifications.soundMuted
        }
    }

    // Anti-serial-conflict timer — owned by overlayManager logic but must live in ShellRoot
    Timer {
        id: overlayOpenTimer
        interval: 50
        repeat: false
        onTriggered: overlayManager._doOpen(overlayManager._pendingOpen)
    }

    QtObject {
        id: overlayManager

        property string activeOverlay: ""
        property string _pendingOpen: ""

        function open(name) {
            if (activeOverlay === name) { _closeActive(); return }
            _closeActive()
            _pendingOpen = name
            overlayOpenTimer.restart()
        }

        function close(name) {
            if (activeOverlay === name) { _closeActive() }
        }

        function closeAll() { _closeActive() }

        function _closeActive() {
            // Clear activeOverlay first to prevent re-entrant calls from closed() signals
            const current = activeOverlay
            activeOverlay = ""
            if (current === "launcher")  launcher.visible = false
            if (current === "powermenu") bar.closePowerMenu()
            if (current === "mpris")     bar.closeMpris()
        }

        function _doOpen(name) {
            if (name === "launcher")  launcher.toggleOpen()
            if (name === "powermenu") bar.openPowerMenu()
            if (name === "mpris")     bar.openMpris()
            activeOverlay = name
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (["workspace","workspacev2","moveworkspace","movewindow","activewindow","fullscreen"].includes(n))
                overlayManager.closeAll()
        }
    }

    Bar { id: bar }

    Connections {
        target: bar
        function onMprisToggleRequested() { overlayManager.open("mpris") }
        function onPowerMenuClosed() { overlayManager.close("powermenu") }
        function onMprisClosed() { overlayManager.close("mpris") }
    }

    LauncherCentered {
        id: launcher
        onDismissed: overlayManager.close("launcher")
        onOutsideClicked: (x, y) => {
            const inBar = y < Theme.barRailHeight
            if (inBar && x >= bar.powerBtnGlobalX) {
                overlayManager.open("powermenu")
            } else if (inBar && bar.mprisChipActive
                       && x >= bar.mprisChipGlobalX - bar.mprisChipWidth / 2
                       && x <= bar.mprisChipGlobalX + bar.mprisChipWidth / 2) {
                bar.setMprisAnchor()
                overlayManager.open("mpris")
            }
        }
    }

    Notifications { id: notifications }

    OsdWindow {}
}
