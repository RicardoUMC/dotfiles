import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../theme"

// Right-island control-center content, rendered inside the owning Bar's
// surface. The per-screen Bar is the single input-authority surface: the RCC
// owns no PanelWindow of its own, so every island interaction (chips, power
// pill, outside-click backdrop, Escape) resolves inside one input tree instead
// of racing between two competing fullscreen surfaces. Compact right-island
// icons deep-link here while preserving the plain Control Center landing state.
Item {
    id: root

    // Fill the Bar surface but sit below its sections/tabs in hit order, so
    // the island chips and power pill keep receiving clicks directly.
    anchors.fill: parent
    z: -1

    // Real open-state flag (replaces the old popup.visible-derived value).
    property bool isOpen: false
    property string activeSection: ""
    property var notificationsState: null
    property var systemStatsState: null

    signal opened()
    signal closed()

    function resetSections() {
        wifiCard.expanded = false
        bluetoothCard.expanded = false
        audioCard.panelOpen = false
        notificationCard.expanded = false
        powerCard.selectedIndex = 0
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
        if (activeSection === "power")
            return "Power"
        return "Control Center"
    }

    function activateSection(section) {
        activeSection = section
        resetSections()
        if (section === "wifi")
            wifiCard.expanded = true
        else if (section === "bluetooth")
            bluetoothCard.expanded = true
        else if (section === "notifications")
            notificationCard.expanded = true
        // Power has no service-card expansion state; resetSections() already
        // returned its destructive list to the top item (reboot) so each visit
        // starts fresh instead of remembering a previous selection.
    }

    function runPowerAction(index) {
        // Close the local section before arming the destructive Process so the
        // surface is gone the instant the command starts, matching the previous
        // standalone PowerMenu teardown order (close, then run).
        root.close()
        if (index === 0) rebootCmd.running = true
        else if (index === 1) poweroffCmd.running = true
        else if (index === 2) logoutCmd.running = true
    }

    function restartPanelReveal() {
        panelBody.revealActive = false
        Qt.callLater(() => {
            if (root.isOpen)
                panelBody.revealActive = true
        })
    }

    function open() {
        if (root.isOpen) return
        activeSection = ""
        resetSections()
        isOpen = true
        opened()
        restartPanelReveal()
        keyHandler.forceActiveFocus()
    }

    function openSection(section) {
        activateSection(section)
        if (!isOpen) {
            isOpen = true
            opened()
            restartPanelReveal()
        }
        // Already open: keep the reveal state intact so a sibling switch only
        // re-resolves content and lets height transition naturally, instead of
        // collapsing and re-growing the whole panel.
        keyHandler.forceActiveFocus()
    }

    function close() {
        if (!isOpen) return
        isOpen = false
        panelBody.revealActive = false
        closed()
    }

    function toggle() {
        if (isOpen) close()
        else open()
    }

    // Full-surface outside-click backdrop. Geometry (not visibility) drives
    // the Bar's composed mask: Region{item} reconnects to x/y/width/height
    // changes only and is visibility-blind, so the backdrop collapses to 0x0
    // while closed (empty input region). visible/enabled must track the same
    // isOpen flag so the input region and any consuming item appear and
    // disappear together.
    MouseArea {
        id: backdrop
        x: 0
        y: 0
        width: root.isOpen ? root.width : 0
        height: root.isOpen ? root.height : 0
        visible: root.isOpen
        enabled: root.isOpen
        onClicked: root.close()
    }

    // Exposed for Bar.qml's composed mask.
    readonly property alias backdropItem: backdrop

    // Window-level OnDemand focus is handled by the Bar surface; this item is
    // the in-surface focus target for Escape-to-close.
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            } else if (root.activeSection === "power") {
                if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                    powerCard.selectedIndex = (powerCard.selectedIndex + 1) % powerCard.itemCount
                    event.accepted = true
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    powerCard.selectedIndex = (powerCard.selectedIndex - 1 + powerCard.itemCount) % powerCard.itemCount
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.runPowerAction(powerCard.selectedIndex)
                    event.accepted = true
                }
            }
        }
    }

    Rectangle {
        id: panelBody
        anchors {
            top: parent.top
            right: parent.right
            topMargin: Theme.barHeight + Theme.rightPanelTopMargin
            rightMargin: Theme.rightPanelRightMargin
        }
        // Above the backdrop so the body consumes its own clicks instead of
        // the outside-click dismiss.
        z: 1
        width: root.activeSection === "power"
            ? Theme.rightPanelPowerWidth + Theme.rightPanelPadding * 2
            : Theme.rightPanelWidth
        property bool revealActive: false
        readonly property real contentAwareHeight: contentColumn.implicitHeight + Theme.rightPanelPadding * 2
        readonly property real aggregateMinimumHeight: root.activeSection === "" ? Math.min(Theme.rightPanelMaxHeight, root.height * 0.6) : 0
        readonly property real targetHeight: Math.min(Theme.rightPanelMaxHeight, Math.max(aggregateMinimumHeight, contentAwareHeight))
        height: revealActive ? targetHeight : 0

        // The body height is content-driven: expanding a specialty card or
        // switching sections re-resolves targetHeight. A fresh open resets
        // revealActive so the body grows from zero; an already-open sibling
        // switch keeps revealActive intact and lets the Spatial transition
        // move between the old and new content heights directly. close()
        // clears revealActive synchronously so the body collapses with the
        // backdrop.
        Behavior on height {
            Motion.Spatial { }
        }
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

        // Content owns the interactive cards; keep it above the body catcher so
        // nested MouseAreas receive clicks instead of the panel's sink handler.
        Flickable {
            id: contentScroller
            z: 1
            anchors { fill: parent; margins: Theme.rightPanelPadding }
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn
                width: contentScroller.width
                spacing: Theme.rightPanelCardGap

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.spacingSm
                    text: root.titleText()
                    color: Colors.text
                    font { family: Colors.displayFont; pixelSize: Theme.fontSizeBodyLg }
                }

                WifiControlCard {
                    id: wifiCard
                    visible: root.activeSection !== "power" && (root.activeSection === "" || root.activeSection === "wifi")
                    Layout.fillWidth: true
                    standalone: root.activeSection === "wifi"
                }

                BluetoothControlCard {
                    id: bluetoothCard
                    visible: root.activeSection !== "power" && (root.activeSection === "" || root.activeSection === "bluetooth")
                    Layout.fillWidth: true
                    standalone: root.activeSection === "bluetooth"
                }

                AudioControlCard {
                    id: audioCard
                    visible: root.activeSection !== "power" && (root.activeSection === "" || root.activeSection === "audio")
                    Layout.fillWidth: true
                    // Audio opens in its summary state; the hero/chevron
                    // performs the second-step expansion for routing/details.
                    standalone: false
                }

                NotificationControlCard {
                    id: notificationCard
                    visible: root.activeSection !== "power" && (root.activeSection === "" || root.activeSection === "notifications")
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

                // Power section content, moved here from the former standalone
                // PowerMenu surface. The RCC body reveals it in place instead
                // of mapping a second fullscreen surface. In power mode the
                // panel narrows to rightPanelPowerWidth and the card fills that
                // compact width.
                Rectangle {
                    id: powerCard
                    visible: root.activeSection === "power"
                    Layout.fillWidth: true
                    Layout.preferredHeight: powerColumn.implicitHeight + Theme.spacingLg
                    radius: Theme.radiusLg
                    color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.rightPanelCardFillOpacity)

                    property int selectedIndex: 0
                    readonly property int itemCount: 3

                    ColumnLayout {
                        id: powerColumn
                        anchors { fill: parent; margins: Theme.spacingSm }
                        spacing: Theme.spacingXs

                        PowerMenuItem {
                            icon: "󰜉"
                            label: "Reiniciar"
                            selected: powerCard.selectedIndex === 0
                            onActivated: root.runPowerAction(0)
                        }

                        PowerMenuItem {
                            icon: "󰐥"
                            label: "Apagar"
                            danger: true
                            selected: powerCard.selectedIndex === 1
                            onActivated: root.runPowerAction(1)
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.2)
                        }

                        PowerMenuItem {
                            icon: "󰍃"
                            label: "Cerrar sesión"
                            selected: powerCard.selectedIndex === 2
                            onActivated: root.runPowerAction(2)
                        }
                    }

                    // Debug visual bounds overlay (development scaffolding)
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

    Process { id: rebootCmd;  command: ["systemctl", "reboot"] }
    Process { id: poweroffCmd; command: ["systemctl", "poweroff"] }
    Process { id: logoutCmd;  command: ["hyprctl", "dispatch", "exit"] }
}
