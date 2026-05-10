import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto
    implicitHeight: 37
    margins { top: 0; left: 0; right: 0 }
    color: "transparent"

    signal powerMenuOpened()
    function closePowerMenu() { powerMenu.close() }
    function openPowerMenu() { powerMenu.open() }
    readonly property bool powerMenuVisible: powerMenu.isOpen
    readonly property real powerBtnGlobalX: root.width - 28 - 12

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
            topMargin: 10
            bottomMargin: 0
        }
        spacing: 0

        Workspaces { Layout.alignment: Qt.AlignVCenter }

        Item { Layout.fillWidth: true }

        SystemStats { Layout.alignment: Qt.AlignVCenter }

        Item { width: 8 }

        PowerMenu {
            id: powerMenu
            Layout.alignment: Qt.AlignVCenter
            onOnOpened: root.powerMenuOpened()
        }
    }
}
