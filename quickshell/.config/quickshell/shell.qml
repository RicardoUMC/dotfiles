// Shell — punto de entrada de Quickshell
import QtQuick
import Quickshell
import Quickshell.Io
import "bar"
import "launcher"
import "theme"

ShellRoot {
    // IPC handler — permite toggle desde hyprland.conf via:
    // quickshell ipc call launcher toggle
    IpcHandler {
        target: "launcher"
        function toggle() {
            launcher.toggleOpen()
        }
    }

    Bar {}

    // Launcher centrado
    LauncherCentered {
        id: launcher
    }
}
