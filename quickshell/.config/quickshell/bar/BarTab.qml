import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property bool compact: false
    property bool silhouetteOnly: true

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
