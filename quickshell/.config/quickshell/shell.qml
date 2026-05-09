import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "bar"
import "launcher"
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
            }
        }
    }

    Bar { id: bar }

    Connections {
        target: bar
        function onPowerMenuOpened() {
            launcher.visible = false
        }
    }

    // Full-screen transparent backdrop — intercepts clicks outside open popups.
    // Covers the bar too; power button clicks are detected by coordinates.
    PanelWindow {
        id: backdrop
        color: "transparent"
        visible: launcher.visible || bar.powerMenuVisible
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                const inBar = mouse.y < 37
                const inPowerBtn = inBar && mouse.x >= bar.powerBtnGlobalX

                launcher.visible = false
                bar.closePowerMenu()

                if (inPowerBtn) powerMenuOpenTimer.start()
            }
        }
    }

    LauncherCentered { id: launcher }
}
