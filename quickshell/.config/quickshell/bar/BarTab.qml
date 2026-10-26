import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property bool compact: false
    // Vertical bars use the same children and spacing, but stack them along
    // the output edge instead of rotating the finished bar.
    property bool vertical: false
    property string edge: "top"
    property bool motionEnabled: true
    property bool hoverEnabled: false
    readonly property bool hovered: tabHoverHandler.hovered
    property real visualScaleX: 1
    property real visualScaleY: 1
    property real visualOriginX: width / 2
    property real visualOriginY: height / 2
    property int visualScaleXDelay: 0
    property int visualScaleYDelay: 0
    // Interactive descendants stay untransformed so nested MouseAreas keep
    // their native hit coordinates during island reveal. The owning
    // BarSection mask supplies the bounded visual growth; BarTab opacity
    // supplies the independent content fade.
    readonly property bool visualSettled: true

    HoverHandler {
        id: tabHoverHandler
        enabled: root.hoverEnabled
    }

    property int paddingH: vertical ? (compact ? Theme.tabPaddingV : Theme.tabPaddingV * 2) : Theme.tabPaddingH
    property int paddingV: vertical ? Theme.tabPaddingH : (compact ? Theme.tabPaddingV : Theme.tabPaddingV * 2)

    // Debug visual bounds overlay (development scaffolding)
    // Matches the tab's bottom radius; top is 0 since the tab connects to the rail
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        // Horizontal tabs keep the accepted top-square/bottom-rounded bounds.
        // Lateral tabs expose square corners at the monitor edge and rounded
        // corners on the inward-facing edge.
        topLeftRadius: root.vertical
            ? (root.edge === "left" ? 0 : Theme.tabRadius) : 0
        topRightRadius: root.vertical
            ? (root.edge === "right" ? 0 : Theme.tabRadius) : 0
        bottomLeftRadius: root.vertical
            ? (root.edge === "left" ? 0 : Theme.tabRadius) : Theme.tabRadius
        bottomRightRadius: root.vertical
            ? (root.edge === "right" ? 0 : Theme.tabRadius) : Theme.tabRadius
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
