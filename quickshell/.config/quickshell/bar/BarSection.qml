import QtQuick
import QtQuick.Effects
import "../theme"

Item {
    id: root

    required property Item targetItem
    property string sectionId: "center"
    property string cornerStyle: "notch"
    property real collapsedHeight: 0
    property bool hasWrap: false
    property bool leftCornerEnabled: true
    property bool rightCornerEnabled: true
    property bool bottomLeftRounded: true
    property bool bottomRightRounded: true

    readonly property real reservedHeight: collapsedHeight
    readonly property Item hit: hitBox
    readonly property real centerX: targetItem.x
    readonly property real centerWidth: targetItem.width
    readonly property real centerHeight: targetItem.height

    readonly property real _cornerSize: Math.min(Theme.barCurveRadius, targetItem.height)
    readonly property real _leftExtent: leftCornerEnabled ? _cornerSize : 0
    readonly property real _rightExtent: rightCornerEnabled ? _cornerSize : 0
    readonly property real _wrapDepth: hasWrap ? Theme.barWrapDepth : 0
    readonly property color _segmentFill: Theme.debugBarSilhouette
        ? Qt.rgba(1.0, 0.2, 0.2, 0.65)
        : Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.tabBgOpacity)

    x: targetItem.x - _leftExtent
    y: targetItem.y
    width: targetItem.width + _leftExtent + _rightExtent
    height: targetItem.height + _wrapDepth

    Item {
        id: targetProxy
        x: root._leftExtent
        y: 0
        width: root.targetItem.width
        height: root.targetItem.height
        visible: false
    }

    Rectangle {
        id: bgSource
        anchors.fill: parent
        visible: false
        layer.enabled: true
        color: root._segmentFill
    }

    Item {
        id: sectionMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        NotchIslandMask {
            targetItem: targetProxy
            cornerSize: root._cornerSize
            leftCornerEnabled: root.leftCornerEnabled
            rightCornerEnabled: root.rightCornerEnabled
            bottomLeftRounded: root.bottomLeftRounded
            bottomRightRounded: root.bottomRightRounded
        }

        NotchCornerMask {
            x: targetProxy.x
            y: targetProxy.y + targetProxy.height
            width: root._cornerSize
            height: root._wrapDepth
            radius: root._cornerSize
            corner: "topLeft"
            color: "white"
            visible: root.hasWrap && !root.bottomLeftRounded && width > 0 && height > 0
        }

        NotchCornerMask {
            x: targetProxy.x + targetProxy.width - width
            y: targetProxy.y + targetProxy.height
            width: root._cornerSize
            height: root._wrapDepth
            radius: root._cornerSize
            corner: "topRight"
            color: "white"
            visible: root.hasWrap && !root.bottomRightRounded && width > 0 && height > 0
        }
    }

    MultiEffect {
        source: bgSource
        maskEnabled: true
        maskSource: sectionMask
        anchors.fill: parent
        visible: Theme.barStyle === "silhouette"
    }

    Item {
        id: hitBox
        anchors.fill: parent
    }
}
