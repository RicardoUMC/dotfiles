import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property real bgOpacity:     Theme.islandBgOpacity
    property real borderOpacity: Theme.islandBorderOpacity
    property real blurRadius:    Theme.islandBlur

    property bool compact: false

    property int paddingH: Theme.tabPaddingH
    property int paddingV: compact ? Theme.tabPaddingV : Theme.tabPaddingV * 2

    // Debug visual bounds overlay (development scaffolding)
    // Matches the tab's bottom radius; top is 0 since the tab connects to the rail
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        topLeftRadius:     0
        topRightRadius:    0
        bottomLeftRadius:  Theme.tabRadius
        bottomRightRadius: Theme.tabRadius
        border {
            width: Theme.debugBorderWidth
            color: Theme.debugBorderColor
        }
        visible: Theme.debugVisualBounds
        z: 999
    }

    // Children placed here are laid out in a row inside the tab
    default property alias contentData: innerRow.data

    implicitWidth:  innerRow.implicitWidth  + paddingH * 2
    implicitHeight: innerRow.implicitHeight + paddingV * 2

    // Background — solid color, opaque to avoid alpha-stacking seam with rail
    Rectangle {
        id: bgSource
        anchors.fill: parent
        topLeftRadius:     0
        topRightRadius:    0
        bottomLeftRadius:  Theme.tabRadius
        bottomRightRadius: Theme.tabRadius
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.tabBgOpacity)
    }

    // Crisp border ring on top
    Rectangle {
        anchors.fill: parent
        topLeftRadius:     0
        topRightRadius:    0
        bottomLeftRadius:  Theme.tabRadius
        bottomRightRadius: Theme.tabRadius
        color: "transparent"
        border {
            width: 1
            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, root.borderOpacity)
        }
    }

    RowLayout {
        id: innerRow
        anchors {
            fill: parent
            leftMargin:   root.paddingH
            rightMargin:  root.paddingH
            topMargin:    root.paddingV
            bottomMargin: root.paddingV
        }
        spacing: Theme.spacingSm
    }
}
