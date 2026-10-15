import QtQuick
import QtQuick.Layouts
import "../services"
import "../theme"
import "."

// Reusable endpoint host for service chips plus the destructive power trigger.
// Bar owns placement and routing; this component owns only service presentation
// and exposes its power button so whichever endpoint is active remains routable.
GridLayout {
    id: root

    property bool vertical: false
    property string barPosition: "top"
    property string dividerMode: "arc"
    property bool motionEnabled: true
    property var notificationsState: null

    signal sectionRequested(string section)

    readonly property Item powerButton: powerMenu

    columns: root.vertical ? 1 : -1
    rows: root.vertical ? -1 : 1
    rowSpacing: Theme.spacingSm
    columnSpacing: Theme.spacingSm

    RightIslandIconButton {
        icon: WifiService.wifiEnabled ? root.wifiSignalGlyph(WifiService.activeSignal) : "󰤭"
        label: "Wi-Fi"
        disabled: !WifiService.wifiEnabled
        active: WifiService.wifiEnabled && WifiService.activeSsid.length > 0
        motionEnabled: root.motionEnabled
        onClicked: root.sectionRequested("wifi")
    }

    RightIslandIconButton {
        icon: BluetoothService.bluetoothEnabled ? "󰂯" : "󰂲"
        label: "Bluetooth"
        disabled: !BluetoothService.bluetoothEnabled
        active: BluetoothService.bluetoothEnabled && (BluetoothService.connectedDevices || []).length > 0
        motionEnabled: root.motionEnabled
        onClicked: root.sectionRequested("bluetooth")
    }

    RightIslandIconButton {
        icon: AudioService.outputMuted ? "󰝟" : "󰕾"
        label: "Audio"
        active: !AudioService.outputMuted
        warning: AudioService.outputMuted
        motionEnabled: root.motionEnabled
        onClicked: root.sectionRequested("audio")
    }

    RightIslandIconButton {
        icon: root.notificationsState && root.notificationsState.doNotDisturb ? "󰂛" : "󰂚"
        label: "Notifications"
        active: root.notificationsState && root.notificationsState.recentModel
            && root.notificationsState.recentModel.count > 0
        motionEnabled: root.motionEnabled
        warning: root.notificationsState && (root.notificationsState.doNotDisturb
            || root.notificationsState.soundMuted)
        onClicked: root.sectionRequested("notifications")
    }

    ServiceDivider {
        vertical: root.vertical
        edge: root.barPosition
        mode: root.dividerMode
        Layout.alignment: Qt.AlignVCenter
    }

    PowerMenu {
        id: powerMenu
        onToggleRequested: root.sectionRequested("power")
    }

    function wifiSignalGlyph(signal) {
        const value = Math.max(0, Number(signal || 0))
        if (value < 20) return "󰤯"
        if (value < 40) return "󰤟"
        if (value < 60) return "󰤢"
        if (value < 80) return "󰤥"
        return "󰤨"
    }
}
