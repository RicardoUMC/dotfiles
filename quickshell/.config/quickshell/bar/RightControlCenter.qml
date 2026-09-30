import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

// Right island control-center shell. Compact right-island icons can
// deep-link here while preserving the plain Control Center landing state.
Item {
    id: root

    implicitWidth: 1
    implicitHeight: 1

    property bool rightControlCenterOpen: popup.visible
    property string activeSection: ""
    property var notificationsState: null
    property var systemStatsState: null

    // Wayland output this overlay pins itself to, passed down from the Bar
    // instance that owns it. An unpinned layer-shell surface sends a null
    // wl_output to get_layer_surface, so the compositor picks the screen.
    property var screenTarget: null

    signal opened()
    signal closed()

    function resetSections() {
        wifiCard.expanded = false
        bluetoothCard.expanded = false
        audioCard.panelOpen = false
        notificationCard.expanded = false
    }

    function titleText() {
        if (activeSection === "wifi")
            return "Wi-Fi"
        if (activeSection === "bluetooth")
            return "Bluetooth"
        if (activeSection === "audio")
            return "Audio"
        if (activeSection === "notifications")
            return "Notifications"
        return "Control Center"
    }

    function activateSection(section) {
        activeSection = section
        resetSections()
        if (section === "wifi")
            wifiCard.expanded = true
        else if (section === "bluetooth")
            bluetoothCard.expanded = true
        else if (section === "audio")
            audioCard.panelOpen = true
        else if (section === "notifications")
            notificationCard.expanded = true
    }

    function open() {
        activeSection = ""
        resetSections()
        if (popup.visible) return
        popup.visible = true
        opened()
    }

    function openSection(section) {
        activateSection(section)
        if (!popup.visible) {
            popup.visible = true
            opened()
        }
    }

    function close() {
        if (!popup.visible) return
        popup.visible = false
        closed()
    }

    function toggle() {
        if (popup.visible) close()
        else open()
    }

    readonly property bool isOpen: popup.visible

    PanelWindow {
        id: popup
        visible: false
        // Null keeps the compositor-picks-output default; a screen pins it.
        screen: root.screenTarget
        color: "transparent"
        // Layer rule: transient system feedback (toasts, OSD) owns Overlay; interactive panels are Top.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: if (visible) keyHandler.forceActiveFocus()

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: panelBody
            anchors {
                top: parent.top
                right: parent.right
                topMargin: Theme.barHeight + Theme.spacingMd - 1
                rightMargin: Theme.spacingMd - 1
            }
            // TODO(right-control-center): promote width/height to Theme/config tokens
            // when this panel graduates from structural shell to configurable UI.
            width: 420
            readonly property real contentAwareHeight: contentColumn.implicitHeight + Theme.spacingMd * 2
            readonly property real aggregateMinimumHeight: root.activeSection === "" ? Math.min(600, popup.height * 0.6) : 0
            height: Math.min(600, Math.max(aggregateMinimumHeight, contentAwareHeight))
            radius: Theme.dashboardBodyRadius
            color: Qt.rgba(Colors.base00.r, Colors.base00.g, Colors.base00.b, Theme.rightPanelOpacity)
            border {
                width: Theme.dashboardBodyBorderWidth
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            Flickable {
                id: contentScroller
                anchors { fill: parent; margins: Theme.spacingMd }
                clip: true
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: contentColumn
                    width: contentScroller.width
                    spacing: Theme.spacingSm

                    Text {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Theme.spacingXs
                        text: root.titleText()
                        color: Colors.text
                        font { family: Colors.displayFont; pixelSize: Theme.fontSizeBody }
                    }

                    WifiControlCard {
                        id: wifiCard
                        visible: root.activeSection === "" || root.activeSection === "wifi"
                        Layout.fillWidth: true
                        standalone: root.activeSection === "wifi"
                    }

                    BluetoothControlCard {
                        id: bluetoothCard
                        visible: root.activeSection === "" || root.activeSection === "bluetooth"
                        Layout.fillWidth: true
                        standalone: root.activeSection === "bluetooth"
                    }

                    AudioControlCard {
                        id: audioCard
                        visible: root.activeSection === "" || root.activeSection === "audio"
                        Layout.fillWidth: true
                        standalone: root.activeSection === "audio"
                    }

                    NotificationControlCard {
                        id: notificationCard
                        visible: root.activeSection === "" || root.activeSection === "notifications"
                        Layout.fillWidth: true
                        standalone: root.activeSection === "notifications"
                        notificationsState: root.notificationsState
                    }

                    MetricsControlCard {
                        id: metricsCard
                        visible: root.activeSection === ""
                        Layout.fillWidth: true
                        systemStatsState: root.systemStatsState
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: parent.radius
                border {
                    width: Theme.debugBorderWidth
                    color: Theme.debugBorderColor
                }
                visible: Theme.debugVisualBounds
                z: 999
            }
        }
    }
}
