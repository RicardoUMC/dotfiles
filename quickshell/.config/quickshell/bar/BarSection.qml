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
    property bool vertical: false
    property string edge: "top"

    readonly property real reservedHeight: vertical ? targetItem.width : collapsedHeight
    readonly property real reservedWidth: vertical ? targetItem.width : 0
    readonly property Item hit: hitBox
    readonly property real centerX: targetItem.x
    readonly property real centerY: targetItem.y
    readonly property real centerWidth: targetItem.width
    readonly property real centerHeight: targetItem.height

    readonly property real _cornerSize: Math.min(Theme.barCurveRadius, vertical ? targetItem.width : targetItem.height)
    readonly property real _leftExtent: leftCornerEnabled ? _cornerSize : 0
    readonly property real _rightExtent: rightCornerEnabled ? _cornerSize : 0
    readonly property real _wrapDepth: hasWrap ? Theme.barWrapDepth : 0
    readonly property color _segmentFill: Theme.debugBarSilhouette
        ? Qt.rgba(1.0, 0.2, 0.2, 0.65)
        : Theme.surface(Colors.base01)

    x: vertical
        ? (edge === "right" ? targetItem.x - _wrapDepth : targetItem.x)
        : targetItem.x - _leftExtent
    y: vertical ? targetItem.y - _leftExtent : targetItem.y - (edge === "bottom" ? _wrapDepth : 0)
    width: vertical ? targetItem.width + _wrapDepth : targetItem.width + _leftExtent + _rightExtent
    height: vertical ? targetItem.height + _leftExtent + _rightExtent : targetItem.height + _wrapDepth

    Item {
        id: targetProxy
        // Keep the target at the output edge on the left, but make room for
        // the inward wrap before it on the right.
        x: root.vertical ? (root.edge === "right" ? root._wrapDepth : 0) : root._leftExtent
        y: root.vertical ? root._leftExtent : (root.edge === "bottom" ? root._wrapDepth : 0)
        width: root.targetItem.width
        height: root.targetItem.height
        visible: false
    }

    Rectangle {
        id: bgSource
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        color: root._segmentFill
    }

    Item {
        id: sectionMask
        anchors.fill: parent
        visible: Theme.debugBarSilhouette
        z: Theme.debugBarSilhouette ? 10 : 0
        layer.enabled: !Theme.debugBarSilhouette
        layer.smooth: true

        NotchIslandMask {
            targetItem: targetProxy
            cornerSize: root._cornerSize
            leftCornerEnabled: root.leftCornerEnabled
            rightCornerEnabled: root.rightCornerEnabled
            bottomLeftRounded: root.bottomLeftRounded
            bottomRightRounded: root.bottomRightRounded
            maskColor: Theme.debugBarSilhouette ? Qt.rgba(1.0, 0.2, 0.2, 0.65) : "white"
            vertical: root.vertical
            edge: root.edge
        }

        // The wrap follows the owning output edge: below for top, above for
        // bottom, and inward for the existing right vertical path.
        NotchCornerMask {
            x: root.vertical ? (root.edge === "left" ? targetProxy.x + targetProxy.width : targetProxy.x - root._wrapDepth) : targetProxy.x
            y: root.vertical ? targetProxy.y : (root.edge === "bottom" ? targetProxy.y - root._wrapDepth : targetProxy.y + targetProxy.height)
            width: root.vertical ? root._wrapDepth : root._cornerSize
            height: root.vertical ? root._cornerSize : root._wrapDepth
            radius: root._cornerSize
            corner: root.vertical ? (root.edge === "left" ? "topLeft" : "topRight") : "topLeft"
            transform: Scale {
                origin.x: (root.vertical ? root._wrapDepth : root._cornerSize) / 2
                origin.y: (root.vertical ? root._cornerSize : root._wrapDepth) / 2
                yScale: !root.vertical && root.edge === "bottom" ? -1 : 1
            }
            color: Theme.debugBarSilhouette ? Qt.rgba(1.0, 0.2, 0.2, 0.65) : "white"
            visible: root.hasWrap && ((root.vertical && root.edge !== "left") || (!root.vertical && !root.bottomLeftRounded)) && width > 0 && height > 0
        }

        NotchCornerMask {
            x: root.vertical ? (root.edge === "left" ? targetProxy.x + targetProxy.width : targetProxy.x - root._wrapDepth) : targetProxy.x + targetProxy.width - width
            y: root.vertical ? targetProxy.y + targetProxy.height - height : (root.edge === "bottom" ? targetProxy.y - root._wrapDepth : targetProxy.y + targetProxy.height)
            width: root.vertical ? root._wrapDepth : root._cornerSize
            height: root.vertical ? root._cornerSize : root._wrapDepth
            radius: root._cornerSize
            corner: root.vertical ? (root.edge === "left" ? "bottomLeft" : "bottomRight") : "topRight"
            transform: Scale {
                origin.x: (root.vertical ? root._wrapDepth : root._cornerSize) / 2
                origin.y: (root.vertical ? root._cornerSize : root._wrapDepth) / 2
                yScale: !root.vertical && root.edge === "bottom" ? -1 : 1
            }
            color: Theme.debugBarSilhouette ? Qt.rgba(1.0, 0.2, 0.2, 0.65) : "white"
            visible: root.hasWrap && ((root.vertical && root.edge !== "left") || (!root.vertical && !root.bottomRightRounded)) && width > 0 && height > 0
        }
    }

    readonly property bool gpuPrototypeActive: Theme.islandGpuPrototypeTarget === "left"
        && sectionId === "left"

    MultiEffect {
        source: bgSource
        maskEnabled: true
        maskSource: sectionMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        anchors.fill: parent
        visible: Theme.barStyle === "silhouette" && !Theme.debugBarSilhouette && !root.gpuPrototypeActive
    }

    IslandGpuPrototype {
        anchors.fill: parent
        active: root.gpuPrototypeActive
        maskItem: sectionMask
    }

    Item {
        id: hitBox
        anchors.fill: parent
    }
}
