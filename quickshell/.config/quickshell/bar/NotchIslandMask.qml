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
    property color maskColor: "white"

    x: vertical ? targetItem.x : targetItem.x - (leftCornerEnabled ? resolvedCornerSize : 0)
    y: vertical ? ((vertical && edge === "left") ? targetItem.y - (leftCornerEnabled ? resolvedCornerSize : 0) : targetItem.y - (leftCornerEnabled ? resolvedCornerSize : 0)) : targetItem.y
    width: vertical ? ((vertical && edge === "left") ? targetItem.width : targetItem.width) : targetItem.width
        + (leftCornerEnabled ? resolvedCornerSize : 0)
        + (rightCornerEnabled ? resolvedCornerSize : 0)
    height: vertical ? targetItem.height
        + (leftCornerEnabled ? resolvedCornerSize : 0)
        + (rightCornerEnabled ? resolvedCornerSize : 0) : targetItem.height

    // Left is the top horizontal source rotated counter-clockwise around its
    // center. Source width/height are the swapped vertical target dimensions.
    Item {
        id: leftHorizontalSource
        visible: notchIslandMask.vertical && notchIslandMask.edge === "left"
        width: notchIslandMask.height
        height: notchIslandMask.width
        transform: Rotation { angle: -90; origin.x: leftHorizontalSource.width / 2; origin.y: leftHorizontalSource.height / 2 }

        NotchCornerMask {
            id: leftSourceCap
            x: 0
            y: 0
            width: notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
            height: width
            corner: "topRight"
            color: notchIslandMask.maskColor
            visible: width > 0
        }

        Rectangle {
            x: leftSourceCap.width
            y: 0
            width: notchIslandMask.targetItem.height
            height: leftHorizontalSource.height
            color: notchIslandMask.maskColor
            bottomLeftRadius: notchIslandMask.bottomLeftRounded ? notchIslandMask.resolvedCornerSize : 0
            bottomRightRadius: notchIslandMask.bottomRightRounded ? notchIslandMask.resolvedCornerSize : 0
        }

        NotchCornerMask {
            id: leftSourceEndCap
            x: notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
            + notchIslandMask.targetItem.height
            y: 0
            width: notchIslandMask.rightCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
            height: width
            corner: "topLeft"
            color: notchIslandMask.maskColor
            visible: width > 0
        }
    }

    // The legacy top/bottom source remains unchanged; right keeps its prior
    // vertical path. Only the left path is replaced by the rotated source.
    NotchCornerMask {
        id: leftNotchCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width : notchIslandMask.targetItem.x)
            : 0
        y: notchIslandMask.vertical
            ? notchIslandMask.targetItem.y - height
            : 0
        width: notchIslandMask.vertical && !(notchIslandMask.vertical && notchIslandMask.edge === "left")
            ? notchIslandMask.resolvedCornerSize
            : (notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0)
        height: width
        corner: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? "topRight" : "topLeft")
            : "topRight"
        color: notchIslandMask.maskColor
        visible: !(notchIslandMask.vertical && notchIslandMask.edge === "left") && (notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.rightCornerEnabled : notchIslandMask.leftCornerEnabled) && width > 0
            : notchIslandMask.leftCornerEnabled && width > 0)
    }

    Rectangle {
        x: notchIslandMask.vertical ? notchIslandMask.targetItem.x : leftNotchCorner.width
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y : 0
        width: notchIslandMask.vertical ? notchIslandMask.targetItem.width : parent.width - leftNotchCorner.width - rightNotchCorner.width
        height: notchIslandMask.vertical ? notchIslandMask.targetItem.height : parent.height
        color: notchIslandMask.maskColor
        visible: !(notchIslandMask.vertical && notchIslandMask.edge === "left")
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
        width: notchIslandMask.vertical && !(notchIslandMask.vertical && notchIslandMask.edge === "left")
            ? notchIslandMask.resolvedCornerSize
            : (notchIslandMask.rightCornerEnabled ? notchIslandMask.resolvedCornerSize : 0)
        height: width
        corner: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? "bottomRight" : "bottomLeft")
            : "topLeft"
        color: notchIslandMask.maskColor
        visible: !(notchIslandMask.vertical && notchIslandMask.edge === "left") && (notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.rightCornerEnabled : notchIslandMask.leftCornerEnabled) && width > 0
            : notchIslandMask.rightCornerEnabled && width > 0)
    }

    NotchCornerMask {
        id: outerTopCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x : notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width)
            : 0
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y - height : 0
        width: notchIslandMask.vertical && !(notchIslandMask.vertical && notchIslandMask.edge === "left") ? notchIslandMask.resolvedCornerSize : 0
        height: width
        corner: notchIslandMask.edge === "left" ? "topLeft" : "topRight"
        color: notchIslandMask.maskColor
        visible: notchIslandMask.vertical && !(notchIslandMask.vertical && notchIslandMask.edge === "left") && width > 0
    }

    NotchCornerMask {
        id: outerBottomCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x : notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width)
            : 0
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y + notchIslandMask.targetItem.height : 0
        width: notchIslandMask.vertical && !(notchIslandMask.vertical && notchIslandMask.edge === "left") ? notchIslandMask.resolvedCornerSize : 0
        height: width
        corner: notchIslandMask.edge === "left" ? "bottomLeft" : "bottomRight"
        color: notchIslandMask.maskColor
        visible: notchIslandMask.vertical && !(notchIslandMask.vertical && notchIslandMask.edge === "left") && width > 0
    }
}
