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
        function toggle() {
            bar.closePowerMenu()
            launcherOpenTimer.start()
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle() {
            if (bar.powerMenuVisible) {
                bar.closePowerMenu()
            } else {
                launcher.visible = false
                powerMenuOpenTimer.start()
            }
        }
    }

    // Timers prevent Wayland serial conflicts when switching between popups
    Timer {
        id: launcherOpenTimer
        interval: 50
        repeat: false
        onTriggered: launcher.toggleOpen()
    }

    Timer {
        id: powerMenuOpenTimer
        interval: 50
        repeat: false
        onTriggered: bar.openPowerMenu()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event.name
            if (name === "workspace" || name === "workspacev2"
                || name === "moveworkspace" || name === "movewindow"
                || name === "activewindow" || name === "fullscreen") {
                launcher.visible = false
                bar.closePowerMenu()
                bar.closeMpris()
            }
        }
    }

    IpcHandler {
        target: "notifications"
        function toggleSound() {
            notifications.soundMuted = !notifications.soundMuted
        }
    }

    Bar { id: bar }

    Connections {
        target: bar
        function onPowerMenuOpened() {
            launcher.visible = false
        }
    }

    LauncherCentered {
        id: launcher
        onOutsideClicked: (x, y) => {
            const inPowerBtn = y < 37 && x >= bar.powerBtnGlobalX
            if (inPowerBtn) powerMenuOpenTimer.start()
        }
    }

    Notifications { id: notifications }

    OsdWindow {}
}
