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

    VerticalNotchSource {
        anchors.fill: parent
        targetItem: notchIslandMask.targetItem
        sectionId: notchIslandMask.sectionId
        cornerSize: notchIslandMask.cornerSize
        leftCornerEnabled: notchIslandMask.leftCornerEnabled
        rightCornerEnabled: notchIslandMask.rightCornerEnabled
        bottomLeftRounded: notchIslandMask.bottomLeftRounded
        bottomRightRounded: notchIslandMask.bottomRightRounded
        vertical: notchIslandMask.vertical
        edge: notchIslandMask.edge
        hasWrap: notchIslandMask.hasWrap
        wrapDepth: notchIslandMask.wrapDepth
        wrapRadius: notchIslandMask.wrapRadius
        maskColor: notchIslandMask.maskColor
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
