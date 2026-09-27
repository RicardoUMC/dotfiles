import QtQuick

Item {
    id: notchIslandMask

    required property Item targetItem
    property real cornerSize: 0
    property bool leftCornerEnabled: true
    property bool rightCornerEnabled: true
    property bool bottomLeftRounded: true
    property bool bottomRightRounded: true

    readonly property real resolvedCornerSize: Math.max(0, Math.min(cornerSize, height))

    x: targetItem.x - (leftCornerEnabled ? resolvedCornerSize : 0)
    y: targetItem.y
    width: targetItem.width
        + (leftCornerEnabled ? resolvedCornerSize : 0)
        + (rightCornerEnabled ? resolvedCornerSize : 0)
    height: targetItem.height

    NotchCornerMask {
        id: leftNotchCorner
        anchors.top: parent.top
        anchors.left: parent.left
        width: notchIslandMask.leftCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
        height: width
        corner: "topRight"
        color: "white"
        visible: notchIslandMask.leftCornerEnabled && width > 0
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftNotchCorner.right
        anchors.right: rightNotchCorner.left
        color: "white"
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: notchIslandMask.bottomLeftRounded ? notchIslandMask.resolvedCornerSize : 0
        bottomRightRadius: notchIslandMask.bottomRightRounded ? notchIslandMask.resolvedCornerSize : 0
    }

    NotchCornerMask {
        id: rightNotchCorner
        anchors.top: parent.top
        anchors.right: parent.right
        width: notchIslandMask.rightCornerEnabled ? notchIslandMask.resolvedCornerSize : 0
        height: width
        corner: "topLeft"
        color: "white"
        visible: notchIslandMask.rightCornerEnabled && width > 0
    }
}
