import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property bool compact: false
    // Vertical bars use the same children and spacing, but stack them along
    // the output edge instead of rotating the finished bar.
    property bool vertical: false

    property int paddingH: vertical ? (compact ? Theme.tabPaddingV : Theme.tabPaddingV * 2) : Theme.tabPaddingH
    property int paddingV: vertical ? Theme.tabPaddingH : (compact ? Theme.tabPaddingV : Theme.tabPaddingV * 2)

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

    // GridLayout gives vertical bars a real column rather than rotating the
    // complete bar. Children retain their normal orientation and hit regions.
    default property alias contentData: innerGrid.data

    implicitWidth:  innerGrid.implicitWidth  + paddingH * 2
    implicitHeight: innerGrid.implicitHeight + paddingV * 2

    GridLayout {
        id: innerGrid
        columns: root.vertical ? 1 : -1
        rows: root.vertical ? -1 : 1
        anchors {
            fill: parent
            leftMargin:   root.paddingH
            rightMargin:  root.paddingH
            topMargin:    root.paddingV
            bottomMargin: root.paddingV
        }
        rowSpacing: Theme.spacingSm
        columnSpacing: Theme.spacingSm
    }
}
