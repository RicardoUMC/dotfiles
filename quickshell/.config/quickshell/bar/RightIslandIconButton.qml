import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property bool warning: false
    property color accentColor: warning ? Colors.orange : Colors.accent

    signal clicked()

    Layout.preferredWidth: 28
    implicitWidth: 28
    implicitHeight: Theme.barChipHeight
    radius: Theme.radiusSm
    color: buttonArea.containsMouse || root.active
           ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.active ? 0.22 : Theme.opacityDim)
           : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacityOverlay)
    border.width: Theme.dashboardBodyBorderWidth
    border.color: buttonArea.containsMouse || root.active
                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.active ? 0.58 : 0.42)
                  : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.active || buttonArea.containsMouse ? root.accentColor : Colors.textDim
        font { family: Colors.monoFont; pixelSize: Theme.fontSizeBody }
    }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
