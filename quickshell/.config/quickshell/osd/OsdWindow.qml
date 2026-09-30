import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

PanelWindow {
    id: root
    visible: false
    color: "transparent"

    // Screen targeting is explicit: an unpinned layer-shell surface hands the
    // compositor a null wl_output and lets it pick the monitor. The OSD reports
    // input to the active display, so it belongs on the focused monitor,
    // resolved by matching Hyprland.focusedMonitor.name against ShellScreen.name
    // — never by index, never assuming a monitor count.
    //
    // The result lands in a plain property that `screen` reads, written
    // imperatively instead of binding `screen` to focus state, because
    // ProxyWindowBase::setScreen unmaps and re-maps a surface whose output
    // changes while it is mapped. Resolution runs in show() only while the
    // surface is still unmapped: the OSD is re-triggered by repeated media-key
    // presses, and a pill already on screen keeps the screen it appeared on
    // rather than being torn down and rebuilt under the user. No focused
    // monitor, or one with no matching ShellScreen (a hot-plug race), leaves the
    // current screen untouched — the surface never throws and never vanishes.
    property ShellScreen targetScreen: null
    screen: root.targetScreen

    function resolveTargetScreen() {
        const focused = Hyprland.focusedMonitor
        if (!focused) return
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === focused.name) {
                root.targetScreen = screens[i]
                return
            }
        }
        // Focused monitor with no live ShellScreen: stay on the current screen.
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 80
    margins {
        bottom: 60
        left: 0
        right: 0
    }

    // --- State ---
    // Current presentation mode: "volume" or "brightness". The surface renders one
    // pill and picks its glyph, percentage and styling from this value.
    property string mode: "volume"

    property int  volPct: 0
    property bool muted:  false
    property int  brightPct: 0

    readonly property bool isBrightness: mode === "brightness"
    readonly property int  percent:      isBrightness ? brightPct : volPct
    // Volume dims when muted; brightness dims at zero, where the screen is black.
    readonly property bool dimmed:       isBrightness ? brightPct === 0 : muted

    readonly property string icon: isBrightness
        ? (brightPct === 0 ? "\uf186" : "\uf185")
        : (muted
            ? "\uf6a9"
            : (volPct === 0 ? "\udb80\udf76" : (volPct < 50 ? "\udb80\udf77" : "\udb80\udf78")))

    readonly property string labelText: isBrightness
        ? (brightPct + "%")
        : (muted ? "MUTED" : (volPct + "%"))

    // --- IPC handler ---
    IpcHandler {
        target: "osd"
        function showVolume() {
            root.mode = "volume"
            volumeReader.running = true
            root.show()
        }
        function showBrightness(pct: int) {
            // The bind already resolved the focused monitor and wrote the value through
            // ddcutil, so the OSD just reports what was applied instead of probing a
            // device a second time (which could disagree with the panel that changed).
            root.mode = "brightness"
            root.brightPct = pct
            root.show()
        }
    }

    // --- Read current volume after trigger ---
    Process {
        id: volumeReader
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const m = data.trim().match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (!m) return
                root.volPct = Math.round(parseFloat(m[1]) * 100)
                root.muted  = !!m[2]
                volumeReader.running = false
            }
        }
    }

    // --- Auto-dismiss ---
    Timer {
        id: dismissTimer
        interval: 2500
        repeat: false
        onTriggered: root.visible = false
    }

    function show() {
        // Resolve only while unmapped. Re-pointing a live layer surface is the
        // risky transition, and a re-trigger of a pill that is already on screen
        // must not rebuild it under the user; the next hidden-to-visible
        // transition picks up wherever focus moved.
        if (!visible)
            resolveTargetScreen()
        visible = true
        dismissTimer.restart()
    }

    // --- Visual ---
    Item {
        anchors.centerIn: parent
        implicitWidth:  220
        implicitHeight: 52

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusPill
            color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, 0.92)
            border {
                width: 1
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
            }
        }

        Row {
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: Theme.spacingLg
                right: parent.right
                rightMargin: Theme.spacingLg
            }
            spacing: Theme.spacingMd

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: root.dimmed ? Colors.muted : Colors.blue
                font {
                    family: Colors.monoFont
                    pixelSize: Theme.fontSizeIcon
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Rectangle {
                    width: 140
                    height: 4
                    radius: Theme.radiusPill
                    color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.3)

                    Rectangle {
                        width: parent.width * (root.percent / 100)
                        height: parent.height
                        radius: parent.radius
                        color: root.dimmed ? Colors.muted : Colors.blue
                        opacity: root.dimmed ? 0.35 : 1.0
                    }
                }

                Text {
                    text: root.labelText
                    color: root.dimmed ? Colors.muted : Colors.textDim
                    font {
                        family: Colors.uiFont
                        pixelSize: Theme.fontSizeLabel
                    }
                }
            }
        }
    }
}
