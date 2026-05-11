import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto
    implicitHeight: Theme.barHeight
    margins { top: 0; left: 0; right: 0 }
    color: "transparent"

    signal powerMenuOpened()
    function closePowerMenu() { powerMenu.close() }
    function openPowerMenu() { powerMenu.open() }
    readonly property bool powerMenuVisible: powerMenu.isOpen
    readonly property real powerBtnGlobalX: root.width - 28 - 12

    function closeMpris() { mprisPopup.close() }
    readonly property bool mprisVisible: mprisPopup.isOpen

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.spacingMd
            rightMargin: Theme.spacingMd
            topMargin: 10
            bottomMargin: 0
        }
        spacing: 0

        Workspaces { Layout.alignment: Qt.AlignVCenter }

        Item { Layout.fillWidth: true }

        MprisIndicator {
            id: mprisChip
            Layout.alignment: Qt.AlignVCenter
            onClicked: {
                mprisPopup.anchorX = mprisChip.x + mprisChip.width / 2
                mprisPopup.toggle()
            }
        }

        Item { width: Theme.spacingSm }

        SystemStats { Layout.alignment: Qt.AlignVCenter }

        Item { width: Theme.spacingSm }

        PowerMenu {
            id: powerMenu
            Layout.alignment: Qt.AlignVCenter
            onOnOpened: root.powerMenuOpened()
        }
    }

    MprisPopup {
        id: mprisPopup
    }
}
