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
    property real wrapRadius: 0
    property real maskOffsetX: 0
    property real maskOffsetY: 0
    property real maskWidth: 0
    property real maskHeight: 0
    property color maskColor: "white"

    // BarSection supplies all derived values from IslandGeometry's scalar
    // contract; this mask only renders the canonical shape.
    readonly property real resolvedCornerSize: Math.max(0, cornerSize)
    // The mask item is already positioned at targetItem.x. The right-side
    // proxy x is only a section-local placement value for that outer item; it
    // must not be added again to the vertical body/caps below.
    readonly property real verticalTargetX: edge === "right" ? 0 : targetItem.x
    readonly property real verticalOuterX: edge === "right"
        ? targetItem.width
        : targetItem.x + targetItem.width

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

    // Both lateral edges use the canonical horizontal source. It rotates
    // counter-clockwise once, then mirrors the final physical cross-axis for
    // right. Source width/height are the swapped vertical target dimensions;
    // the full visual section includes its wrap depth.
    Item {
        id: verticalMirror
        visible: notchIslandMask.vertical
        anchors.fill: parent
        transform: Scale {
            origin.x: verticalMirror.width / 2
            origin.y: verticalMirror.height / 2
            xScale: notchIslandMask.edge === "right" ? -1 : 1
        }

        Item {
            id: rotatedHorizontalSource
            width: notchIslandMask.height
            height: notchIslandMask.targetItem.width
                + (notchIslandMask.hasWrap ? notchIslandMask.wrapDepth : 0)
            anchors.centerIn: parent
            transform: Rotation { angle: -90; origin.x: rotatedHorizontalSource.width / 2; origin.y: rotatedHorizontalSource.height / 2 }

            // This is the canonical horizontal top grammar. The source is
            // rotated as one whole source (CCW): (u,v) -> (v,W-u), where W is
            // this source's width. The outer mirror makes right the physical
            // counterpart without changing section-specific endpoint flags.
        NotchCornerMask {
            id: leftSourceCap
            x: 0
            y: 0
            width: notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
            height: width
            // Match the canonical horizontal source: the source-left cap's
            // rounded side faces the body attachment, not the remote tip.
            corner: "topRight"
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
            // Match the canonical source-right cap; this also fixes the
            // physical lower endpoint after the -90-degree rotation.
            corner: "topLeft"
            color: notchIslandMask.maskColor
            visible: width > 0
        }

        NotchCornerMask {
            x: leftSourceCap.width
            y: notchIslandMask.targetItem.width
            width: notchIslandMask.vertical
                ? notchIslandMask.wrapRadius : notchIslandMask.resolvedCornerSize
            height: notchIslandMask.vertical && notchIslandMask.hasWrap
                ? notchIslandMask.wrapDepth : 0
            radius: notchIslandMask.vertical
                ? Math.max(notchIslandMask.resolvedCornerSize,
                          notchIslandMask.wrapDepth,
                          notchIslandMask.wrapRadius)
                : notchIslandMask.resolvedCornerSize
            // Keep the horizontal left-end corner in the checkpoint source;
            // the remaining lower-end refinement is tracked separately.
            corner: "topLeft"
            color: notchIslandMask.maskColor
            visible: notchIslandMask.hasWrap
                && notchIslandMask.bottomLeftRounded === false
                && width > 0 && height > 0
        }

        NotchCornerMask {
            x: leftSourceCap.width + notchIslandMask.targetItem.height - width
            y: notchIslandMask.targetItem.width
            width: notchIslandMask.vertical
                ? notchIslandMask.wrapRadius : notchIslandMask.resolvedCornerSize
            height: notchIslandMask.vertical && notchIslandMask.hasWrap
                ? notchIslandMask.wrapDepth : 0
            radius: notchIslandMask.vertical
                ? Math.max(notchIslandMask.resolvedCornerSize,
                          notchIslandMask.wrapDepth,
                          notchIslandMask.wrapRadius)
                : notchIslandMask.resolvedCornerSize
            // Source-right becomes the physical upper endpoint after the
            // -90-degree mapping, so preserve the horizontal right-end cap.
            corner: notchIslandMask.vertical ? "topRight" : "topLeft"
            color: notchIslandMask.maskColor
            visible: notchIslandMask.hasWrap
                && notchIslandMask.bottomRightRounded === false
                && width > 0 && height > 0
        }
        }
    }

    // The legacy top/bottom source remains unchanged. Both vertical paths use
    // the mirrored canonical source above.
    NotchCornerMask {
        id: leftNotchCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width : notchIslandMask.verticalTargetX)
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
        visible: !notchIslandMask.vertical && notchIslandMask.leftCornerEnabled && width > 0
    }

    Rectangle {
        x: notchIslandMask.vertical ? notchIslandMask.verticalTargetX : leftNotchCorner.width
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y : 0
        width: notchIslandMask.vertical ? notchIslandMask.targetItem.width : parent.width - leftNotchCorner.width - rightNotchCorner.width
        height: notchIslandMask.vertical ? notchIslandMask.targetItem.height : parent.height
        color: notchIslandMask.maskColor
        visible: !notchIslandMask.vertical
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
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x + notchIslandMask.targetItem.width - width : notchIslandMask.verticalTargetX)
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
        visible: !notchIslandMask.vertical && notchIslandMask.rightCornerEnabled && width > 0
    }

    NotchCornerMask {
        id: outerTopCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x : notchIslandMask.verticalOuterX - width)
            : 0
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y - height : 0
        width: notchIslandMask.vertical && !(notchIslandMask.vertical && notchIslandMask.edge === "left") ? notchIslandMask.resolvedCornerSize : 0
        height: width
        corner: notchIslandMask.edge === "left" ? "topLeft" : "topRight"
        color: notchIslandMask.maskColor
        visible: false
    }

    NotchCornerMask {
        id: outerBottomCorner
        x: notchIslandMask.vertical
            ? (notchIslandMask.edge === "left" ? notchIslandMask.targetItem.x : notchIslandMask.verticalOuterX - width)
            : 0
        y: notchIslandMask.vertical ? notchIslandMask.targetItem.y + notchIslandMask.targetItem.height : 0
        width: notchIslandMask.vertical && !(notchIslandMask.vertical && notchIslandMask.edge === "left") ? notchIslandMask.resolvedCornerSize : 0
        height: width
        corner: notchIslandMask.edge === "left" ? "bottomLeft" : "bottomRight"
        color: notchIslandMask.maskColor
        visible: false    }
}
