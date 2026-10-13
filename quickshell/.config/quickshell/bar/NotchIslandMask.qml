import QtQuick

Item {
    id: notchIslandMask

    required property Item targetItem
    property real cornerSize: 0
    property bool leftCornerEnabled: true
    property bool rightCornerEnabled: true
    property bool bottomLeftRounded: true
    property bool bottomRightRounded: true
    property bool vertical: false
    property string edge: "top"

    // BarSection already clamps this radius to the target cross-axis size;
    // keeping the mask independent from its own geometry avoids vertical
    // binding loops when GridLayout resolves tab widths.
    readonly property real resolvedCornerSize: Math.max(0, cornerSize)

    x: vertical ? targetItem.x : targetItem.x - (leftCornerEnabled ? resolvedCornerSize : 0)
    y: vertical ? targetItem.y - (leftCornerEnabled ? resolvedCornerSize : 0) : targetItem.y
    width: vertical ? targetItem.width : targetItem.width
        + (leftCornerEnabled ? resolvedCornerSize : 0)
        + (rightCornerEnabled ? resolvedCornerSize : 0)
    height: vertical ? targetItem.height
        + (leftCornerEnabled ? resolvedCornerSize : 0)
        + (rightCornerEnabled ? resolvedCornerSize : 0) : targetItem.height

    transform: Scale {
        origin.x: notchIslandMask.width / 2
        origin.y: notchIslandMask.height / 2
        yScale: !notchIslandMask.vertical && notchIslandMask.edge === "bottom" ? -1 : 1
    }

    NotchCornerMask {
        id: leftNotchCorner
        // Child coordinates are local to this mask; parent.x/y are the
        // mask's position in BarSection and would offset the ornament twice.
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width : notchIslandMask.targetItem.x)
            : 0
        y: notchIslandMask.vertical
            ? notchIslandMask.targetItem.y - height
            : 0
        width: notchIslandMask.vertical
            ? notchIslandMask.resolvedCornerSize
            : (notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0)
        height: notchIslandMask.vertical
            ? notchIslandMask.resolvedCornerSize
            : width
        corner: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? "topRight" : "topLeft")
            : "topRight"
        color: "white"
        visible: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.rightCornerEnabled : notchIslandMask.leftCornerEnabled) && width > 0
            : notchIslandMask.leftCornerEnabled && width > 0
    }

    Rectangle {
        x: notchIslandMask.vertical ? notchIslandMask.targetItem.x : leftNotchCorner.width
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y : 0
        width: notchIslandMask.vertical ? notchIslandMask.targetItem.width : parent.width - leftNotchCorner.width - rightNotchCorner.width
        height: notchIslandMask.vertical ? notchIslandMask.targetItem.height : parent.height
        color: "white"
        topLeftRadius: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.resolvedCornerSize : 0)
            : 0
        topRightRadius: notchIslandMask.vertical
            ? (notchIslandMask.edge === "right" ? notchIslandMask.resolvedCornerSize : 0)
            : 0
        bottomLeftRadius: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.resolvedCornerSize : 0)
            : (notchIslandMask.bottomLeftRounded ? notchIslandMask.resolvedCornerSize : 0)
        bottomRightRadius: notchIslandMask.vertical
            ? (notchIslandMask.edge === "right" ? notchIslandMask.resolvedCornerSize : 0)
            : (notchIslandMask.bottomRightRounded ? notchIslandMask.resolvedCornerSize : 0)
    }

    NotchCornerMask {
        id: rightNotchCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width : notchIslandMask.targetItem.x)
            : parent.width - width
        y: notchIslandMask.vertical
            ? notchIslandMask.targetItem.y + notchIslandMask.targetItem.height
            : 0
        width: notchIslandMask.vertical
            ? notchIslandMask.resolvedCornerSize
            : (notchIslandMask.rightCornerEnabled ? notchIslandMask.resolvedCornerSize : 0)
        height: notchIslandMask.vertical
            ? notchIslandMask.resolvedCornerSize
            : width
        corner: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? "bottomRight" : "bottomLeft")
            : "topLeft"
        color: "white"
        visible: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.rightCornerEnabled : notchIslandMask.leftCornerEnabled) && width > 0
            : notchIslandMask.rightCornerEnabled && width > 0
    }

    // Vertical islands keep the notch-facing corners above, and add the
    // matching rounded pair on the physical outer edge.
    NotchCornerMask {
        id: outerTopCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x : notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width)
            : 0
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y - height : 0
        width: notchIslandMask.vertical ? notchIslandMask.resolvedCornerSize : 0
        height: notchIslandMask.vertical ? notchIslandMask.resolvedCornerSize : 0
        corner: notchIslandMask.edge === "left" ? "topLeft" : "topRight"
        color: "white"
        visible: notchIslandMask.vertical && width > 0
    }

    NotchCornerMask {
        id: outerBottomCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x : notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width)
            : 0
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y + notchIslandMask.targetItem.height : 0
        width: notchIslandMask.vertical ? notchIslandMask.resolvedCornerSize : 0
        height: notchIslandMask.vertical ? notchIslandMask.resolvedCornerSize : 0
        corner: notchIslandMask.edge === "left" ? "bottomLeft" : "bottomRight"
        color: "white"
        visible: notchIslandMask.vertical && width > 0
    }

}
