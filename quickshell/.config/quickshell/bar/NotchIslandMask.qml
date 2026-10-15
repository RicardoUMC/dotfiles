import QtQuick

Item {
    id: notchIslandMask

    required property Item targetItem
    property string sectionId: "center"
    property real cornerSize: 0
    property bool leftCornerEnabled: true
    property bool rightCornerEnabled: true
    property bool bottomLeftRounded: true
    property bool bottomRightRounded: true
    property bool vertical: false
    property string edge: "top"
    property bool hasWrap: false
    property real wrapDepth: 0
    property real maskOffsetX: 0
    property real maskOffsetY: 0
    property real maskWidth: 0
    property real maskHeight: 0
    property color maskColor: "white"

    // BarSection supplies all derived values from IslandGeometry's scalar
    // contract; this mask only renders the canonical shape.
    readonly property real resolvedCornerSize: Math.max(0, cornerSize)

    x: targetItem.x + maskOffsetX
    y: targetItem.y + maskOffsetY
    width: maskWidth
    height: maskHeight

    // Bottom mirrors the complete horizontal source, preserving the accepted
    // top/bottom notch grammar without changing the lateral source geometry.
    transform: Scale {
        origin.x: notchIslandMask.width / 2
        origin.y: notchIslandMask.height / 2
        yScale: !notchIslandMask.vertical && notchIslandMask.edge === "bottom" ? -1 : 1
    }

    // Left is the top horizontal source rotated counter-clockwise around its
    // center. Source width/height are the swapped vertical target dimensions.
    Item {
        id: leftHorizontalSource
        visible: notchIslandMask.vertical && notchIslandMask.edge === "left"
        width: notchIslandMask.height
        height: notchIslandMask.targetItem.width
            + (notchIslandMask.hasWrap ? notchIslandMask.wrapDepth : 0)
        anchors.centerIn: parent
        transform: Rotation { angle: -90; origin.x: leftHorizontalSource.width / 2; origin.y: leftHorizontalSource.height / 2 }

        // This is the canonical horizontal top grammar. The source is
        // rotated as one whole source (CCW): (u,v) -> (v,W-u), where W is
        // this source's width. Debug and production therefore consume the
        // identical body, cap, and wrap geometry.
        NotchCornerMask {
            id: leftSourceCap
            x: 0
            y: 0
            width: notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
            height: width
            corner: notchIslandMask.vertical
                && notchIslandMask.edge === "left"
                && notchIslandMask.sectionId !== "center" ? "topLeft" : "topRight"
            color: notchIslandMask.maskColor
            visible: width > 0
        }

        Rectangle {
            x: leftSourceCap.width
            y: 0
            width: notchIslandMask.targetItem.height
            height: notchIslandMask.targetItem.width
            color: notchIslandMask.maskColor
            bottomLeftRadius: notchIslandMask.bottomLeftRounded ? notchIslandMask.resolvedCornerSize : 0
            bottomRightRadius: notchIslandMask.bottomRightRounded ? notchIslandMask.resolvedCornerSize : 0
        }

        NotchCornerMask {
            id: leftSourceEndCap
            x: (notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0)
                + notchIslandMask.targetItem.height
            y: 0
            width: notchIslandMask.rightCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
            height: width
            corner: notchIslandMask.vertical
                && notchIslandMask.edge === "left"
                && notchIslandMask.sectionId !== "center" ? "topRight" : "topLeft"
            color: notchIslandMask.maskColor
            visible: width > 0
        }

        NotchCornerMask {
            x: leftSourceCap.width
            y: notchIslandMask.targetItem.width
            width: notchIslandMask.resolvedCornerSize
            height: notchIslandMask.vertical && notchIslandMask.edge === "left"
                && notchIslandMask.hasWrap ? notchIslandMask.wrapDepth : 0
            radius: notchIslandMask.resolvedCornerSize
            corner: "topLeft"
            color: notchIslandMask.maskColor
            visible: notchIslandMask.bottomLeftRounded === false && width > 0 && height > 0
        }

        NotchCornerMask {
            x: leftSourceCap.width + notchIslandMask.targetItem.height - width
            y: notchIslandMask.targetItem.width
            width: notchIslandMask.resolvedCornerSize
            height: notchIslandMask.vertical && notchIslandMask.edge === "left"
                && notchIslandMask.hasWrap ? notchIslandMask.wrapDepth : 0
            radius: notchIslandMask.resolvedCornerSize
            corner: "topRight"
            color: notchIslandMask.maskColor
            visible: notchIslandMask.bottomRightRounded === false && width > 0 && height > 0
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
