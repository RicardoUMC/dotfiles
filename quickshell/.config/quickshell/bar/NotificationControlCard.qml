import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../theme"

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + Theme.spacingSm * 2
    radius: Theme.radiusLg
    color: Theme.rightPanelCardSurface(Colors.base01)
    border.width: Theme.dashboardBodyBorderWidth
    border.color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder * 0.55)

    // notificationsState.recentModel is the persistent notification store, not the
    // live toasts: rows survive toast expiry, DND suppression, and shell reloads.
    property var notificationsState: null
    property bool expanded: false
    property bool standalone: false
    readonly property int maxVisibleNotifications: 3
    // The preview stays the default view; the group-header control reveals the
    // retained history in place and hands the overflow back to the panel scroll.
    property bool showAllNotifications: false
    readonly property int notificationCount: notificationsState && notificationsState.recentModel ? notificationsState.recentModel.count : 0
    readonly property int visibleNotificationCount: showAllNotifications
                                                    ? notificationCount
                                                    : Math.min(maxVisibleNotifications, notificationCount)
    readonly property bool notificationsTruncated: notificationCount > maxVisibleNotifications
    readonly property bool soundMuted: notificationsState ? notificationsState.soundMuted : false
    readonly property bool doNotDisturb: notificationsState ? notificationsState.doNotDisturb : false

    function notificationAt(index) {
        if (!notificationsState || !notificationsState.recentModel)
            return null
        if (index < 0 || index >= notificationsState.recentModel.count)
            return null
        return notificationsState.recentModel.get(index)
    }

    function textOrFallback(value, fallback) {
        const text = String(value || "")
        return text.length > 0 ? text : fallback
    }

    function summaryText() {
        if (root.doNotDisturb)
            return root.notificationCount + " recent • DND on"
        if (root.soundMuted)
            return root.notificationCount + " recent • Sound muted"
        return root.notificationCount === 1 ? "1 recent notification" : root.notificationCount + " recent notifications"
    }

    function urgencyColor(urgency) {
        if (urgency === NotificationUrgency.Critical)
            return Colors.red
        if (urgency === NotificationUrgency.Low)
            return Colors.muted
        return Colors.accent
    }

    onStandaloneChanged: if (standalone) expanded = true
    // Collapse back to the newest-N preview whenever the section closes, so a
    // re-opened panel never resumes in an unannounced full-history mode.
    onExpandedChanged: if (!expanded) showAllNotifications = false
    // History retention only grows the preview until it overflows it; once the
    // store fits the preview again the mode has nothing left to reveal.
    onNotificationCountChanged: {
        if (!notificationsTruncated)
            showAllNotifications = false
    }
    onVisibleChanged: {
        if (!visible)
            expanded = false
        else if (standalone)
            expanded = true
    }

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 2
        radius: Theme.radiusPill
        color: root.doNotDisturb ? Colors.orange : (root.notificationCount > 0 ? Colors.accent : Colors.muted)
        opacity: root.notificationCount > 0 || root.doNotDisturb ? 0.90 : 0.45
    }

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingSm
        spacing: Theme.spacingSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                radius: Theme.radiusMd
                color: mainClickArea.containsMouse || root.expanded
                       ? Theme.surfaceNested(Colors.base02)
                       : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingSm
                    anchors.rightMargin: Theme.spacingSm
                    spacing: Theme.spacingSm

                    Text {
                        text: root.doNotDisturb ? "󰂛" : (root.notificationCount > 0 ? "󰂚" : "󰂜")
                        color: root.doNotDisturb ? Colors.orange : (root.notificationCount > 0 ? Colors.accent : Colors.textDim)
                        font { family: Colors.monoFont; pixelSize: Theme.fontSizeIcon }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Text {
                                Layout.fillWidth: true
                                text: "Notifications"
                                elide: Text.ElideRight
                                color: Colors.text
                                font { family: Colors.uiFont; pixelSize: Theme.fontSizeBodyLg }
                            }

                            Text {
                                text: root.doNotDisturb ? "DND" : String(root.notificationCount)
                                color: root.doNotDisturb ? Colors.orange : (root.notificationCount > 0 ? Colors.green : Colors.textDim)
                                font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.summaryText() + " • View notifications"
                            elide: Text.ElideRight
                            color: Colors.textDim
                            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                        }
                    }
                }

                MouseArea {
                    id: mainClickArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = root.standalone ? true : !root.expanded
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.expanded
            spacing: Theme.spacingSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                NotificationToggleButton {
                    Layout.fillWidth: true
                    label: root.soundMuted ? "Sound muted" : "Sound on"
                    icon: root.soundMuted ? "󰝟" : "󰕾"
                    active: root.soundMuted
                    accentColor: Colors.orange
                    onTriggered: if (root.notificationsState) root.notificationsState.soundMuted = !root.notificationsState.soundMuted
                }

                NotificationToggleButton {
                    Layout.fillWidth: true
                    label: root.doNotDisturb ? "DND on" : "DND off"
                    icon: "󰂛"
                    active: root.doNotDisturb
                    accentColor: Colors.orange
                    onTriggered: if (root.notificationsState) root.notificationsState.doNotDisturb = !root.notificationsState.doNotDisturb
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Text {
                    Layout.fillWidth: true
                    text: root.notificationCount > 0 ? "Recent" : "No recent notifications"
                    color: Colors.textDim
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
                }

                // Group-level reveal for the retained history that the preview
                // hides. Borderless button, same weight as the other cards'
                // header actions; `Clear all` stays the quieter destructive text.
                NotificationPillAction {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.notificationsTruncated
                    label: root.showAllNotifications
                           ? "Show newest " + root.maxVisibleNotifications
                           : "Show all " + root.notificationCount
                    accentColor: Colors.accent
                    onTriggered: root.showAllNotifications = !root.showAllNotifications
                }

                Text {
                    visible: root.notificationCount > 0
                    text: "Clear all"
                    color: clearAllArea.containsMouse ? Colors.red : Colors.textDim
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }

                    MouseArea {
                        id: clearAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.notificationsState) root.notificationsState.clearAll()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.notificationCount === 0
                implicitHeight: 42
                radius: Theme.radiusMd
                color: Theme.surfaceNested(Colors.base02)
                border.width: 0

                Text {
                    anchors.centerIn: parent
                    text: root.doNotDisturb ? "DND is on. New notifications will be collected silently." : "Notifications will appear here."
                    color: Colors.textDim
                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                }
            }

            Repeater {
                model: root.visibleNotificationCount

                delegate: Rectangle {
                    id: notificationRow

                    property int sourceIndex: root.notificationCount - 1 - index
                    property var notificationItem: root.notificationAt(sourceIndex)
                    property color rowAccent: root.urgencyColor(notificationItem ? notificationItem.urgency : NotificationUrgency.Normal)

                    Layout.fillWidth: true
                    implicitHeight: rowContent.implicitHeight + Theme.spacingSm * 2
                    radius: Theme.radiusMd
                    color: rowMouse.containsMouse
                           ? Theme.surfaceNested(Colors.base02)
                           : "transparent"
                    border.width: 0

                    RowLayout {
                        id: rowContent
                        anchors.fill: parent
                        anchors.margins: Theme.spacingSm
                        spacing: Theme.spacingSm

                        Rectangle {
                            Layout.preferredWidth: Theme.spacingXs
                            Layout.fillHeight: true
                            radius: Theme.radiusPill
                            color: notificationRow.rowAccent
                            opacity: 0.82
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSm

                                Text {
                                    Layout.fillWidth: true
                                    text: root.textOrFallback(notificationRow.notificationItem ? notificationRow.notificationItem.summary : "", "Notification")
                                    elide: Text.ElideRight
                                    color: Colors.text
                                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
                                }

                                Text {
                                    text: root.textOrFallback(notificationRow.notificationItem ? notificationRow.notificationItem.appName : "", "App")
                                    elide: Text.ElideRight
                                    color: Colors.textDim
                                    font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: notificationRow.notificationItem && String(notificationRow.notificationItem.body || "").length > 0
                                text: notificationRow.notificationItem ? String(notificationRow.notificationItem.body || "") : ""
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                                color: Colors.textDim
                                font { family: Colors.uiFont; pixelSize: Theme.fontSizeCaption }
                            }
                        }

                        Text {
                            text: "✕"
                            color: dismissArea.containsMouse ? Colors.red : Colors.textDim
                            font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }

                            MouseArea {
                                id: dismissArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.notificationsState) root.notificationsState.dismissAt(notificationRow.sourceIndex)
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }

            // Overflow is now reachable through the `Recent` header control, so
            // no remainder row is rendered here: the list either shows the
            // preview or shows everything.
        }
    }

    // Borderless tinted button: the notification card's group-action vocabulary,
    // transparent until hovered or pressed, tinted by the passed intent color.
    component NotificationPillAction: Rectangle {
        id: pillAction

        property string label: ""
        property color accentColor: Colors.accent

        signal triggered()

        implicitWidth: pillRow.implicitWidth + Theme.spacingMd
        implicitHeight: 26
        radius: Theme.radiusSm
        opacity: enabled ? 1.0 : 0.55
        color: pillClickArea.containsMouse
               ? Qt.rgba(pillAction.accentColor.r, pillAction.accentColor.g, pillAction.accentColor.b, 0.16)
               : "transparent"
        border.width: 0

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spacingXs

            Text {
                text: pillAction.label
                color: pillAction.accentColor
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }
        }

        MouseArea {
            id: pillClickArea
            anchors.fill: parent
            enabled: pillAction.enabled
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: pillAction.triggered()
        }
    }

    component NotificationToggleButton: Rectangle {
        id: toggleButton

        property string label: ""
        property string icon: ""
        property bool active: false
        property color accentColor: Colors.accent
        signal triggered()

        implicitHeight: 32
        radius: Theme.radiusMd
        color: toggleArea.containsMouse || toggleButton.active
               ? Qt.rgba(toggleButton.accentColor.r, toggleButton.accentColor.g, toggleButton.accentColor.b, 0.18)
               : Colors.base02
        border.width: Theme.dashboardBodyBorderWidth
        border.color: Qt.rgba(toggleButton.accentColor.r, toggleButton.accentColor.g, toggleButton.accentColor.b, Theme.opacityBorder * 0.8)

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingXs

            Text {
                text: toggleButton.icon
                color: toggleButton.active ? toggleButton.accentColor : Colors.textDim
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
            }

            Text {
                text: toggleButton.label
                color: Colors.text
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleButton.triggered()
        }
    }
}
