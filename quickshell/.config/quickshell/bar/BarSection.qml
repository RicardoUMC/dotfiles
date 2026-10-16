import QtQuick
import QtQuick.Effects
import "."
import "../theme"

Item {
    id: root

    required property Item targetItem
    property string sectionId: "center"
    property string cornerStyle: "notch"
    property real collapsedHeight: 0
    property real collapsedWidth: collapsedHeight
    property bool hasWrap: false
    // Horizontal callers keep the legacy left/right flags. Vertical callers
    // describe the same source through physical top/bottom semantics.
    property bool leftCornerEnabled: true
    property bool rightCornerEnabled: true
    property bool bottomLeftRounded: true
    property bool bottomRightRounded: true
    property bool topCornerEnabled: true
    property bool bottomCornerEnabled: true
    // On the left edge these are leftTop/leftBottom; on the right edge they
    // describe the mirrored outer side without changing source handedness.
    property bool outerTopRounded: true
    property bool outerBottomRounded: true
    property bool vertical: false
    property string edge: "top"

    function sectionMetric(name) {
        return IslandGeometry.sectionValue(
            name,
            root.vertical,
            root.edge,
            root.targetItem.width,
            root.targetItem.height,
            Theme.barCurveRadius,
            Theme.barWrapDepth,
            root.hasWrap,
            root._sourceLeftCornerEnabled,
            root._sourceRightCornerEnabled,
            root._sourceBottomLeftRounded,
            root._sourceBottomRightRounded,
            root.collapsedHeight,
            root.collapsedWidth)
    }

    // Keep reservation branches short-circuited: horizontal bars must not
    // observe target width while resolving an exclusive zone of zero width.
    readonly property real reservedHeight: root.vertical ? root.targetItem.width : root.collapsedHeight
    readonly property real reservedWidth: root.vertical ? sectionMetric("reservedWidth") : 0
    readonly property Item hit: hitBox
    readonly property real centerX: targetItem.x
    readonly property real centerY: targetItem.y
    readonly property real centerWidth: targetItem.width
    readonly property real centerHeight: targetItem.height

    readonly property real _cornerSize: sectionMetric("corner")
    readonly property real _leftExtent: sectionMetric("leftExtent")
    readonly property real _rightExtent: sectionMetric("rightExtent")
    readonly property real _wrapDepth: sectionMetric("wrapDepth")
    readonly property real _wrapRadius: root.vertical ? Theme.barCurveRadius : root._cornerSize
    // The canonical source is rotated -90 degrees for lateral bars: its
    // source-left endpoint becomes physical bottom, while source-right becomes
    // physical top. Keep physical flags named in the user's screen space.
    readonly property bool _sourceLeftCornerEnabled: root.vertical
        ? root.bottomCornerEnabled : root.leftCornerEnabled
    readonly property bool _sourceRightCornerEnabled: root.vertical
        ? root.topCornerEnabled : root.rightCornerEnabled
    readonly property bool _sourceBottomLeftRounded: root.vertical
        ? root.outerBottomRounded : root.bottomLeftRounded
    readonly property bool _sourceBottomRightRounded: root.vertical
        ? root.outerTopRounded : root.bottomRightRounded
    readonly property real _sectionOffsetX: sectionMetric("sectionOffsetX")
    readonly property real _sectionOffsetY: sectionMetric("sectionOffsetY")
    readonly property real _sectionWidth: sectionMetric("sectionWidth")
    readonly property real _sectionHeight: sectionMetric("sectionHeight")
    readonly property real _targetProxyX: sectionMetric("targetProxyX")
    readonly property real _targetProxyY: sectionMetric("targetProxyY")
    readonly property real _maskOffsetX: sectionMetric("maskOffsetX")
    readonly property real _maskOffsetY: sectionMetric("maskOffsetY")
    readonly property real _maskWidth: sectionMetric("maskWidth")
    readonly property real _maskHeight: sectionMetric("maskHeight")
    readonly property real _targetYFromSection: sectionMetric("targetYFromSection")
    readonly property real _horizontalSourceWidth: sectionMetric("horizontalSourceWidth")
    readonly property real _horizontalSourceHeight: sectionMetric("horizontalSourceHeight")
    readonly property bool _leftWrapEnabled: sectionMetric("leftWrapEnabled")
    readonly property bool _rightWrapEnabled: sectionMetric("rightWrapEnabled")
    readonly property color _segmentFill: Theme.debugBarSilhouette
        ? Qt.rgba(1.0, 0.2, 0.2, 0.65)
        : Theme.surface(Colors.base01)

    x: targetItem.x + _sectionOffsetX
    y: targetItem.y + _sectionOffsetY
    width: _sectionWidth
    height: _sectionHeight

    Item {
        id: targetProxy
        // Keep the target at the output edge on the left, but make room for
        // the inward wrap before it on the right.
        x: root._targetProxyX
        y: root._targetProxyY
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
            sectionId: root.sectionId
            cornerSize: root._cornerSize
            leftCornerEnabled: root._sourceLeftCornerEnabled
            rightCornerEnabled: root._sourceRightCornerEnabled
            bottomLeftRounded: root._sourceBottomLeftRounded
            bottomRightRounded: root._sourceBottomRightRounded
            vertical: root.vertical
            edge: root.edge
            hasWrap: root.hasWrap
            wrapDepth: root._wrapDepth
            wrapRadius: root._wrapRadius
            maskOffsetX: root._maskOffsetX
            maskOffsetY: root._maskOffsetY
            maskWidth: root._maskWidth
            maskHeight: root._maskHeight
            maskColor: Theme.debugBarSilhouette ? Qt.rgba(1.0, 0.2, 0.2, 0.65) : "white"
        }

        // The wrap follows the owning output edge: below for top, above for
        // bottom, and inward for the existing right vertical path.
        NotchCornerMask {
            x: root.vertical ? (root.edge === "left" ? targetProxy.x + targetProxy.width : targetProxy.x - root._wrapDepth) : targetProxy.x
            y: root.vertical ? targetProxy.y : (root.edge === "bottom" ? targetProxy.y - root._wrapDepth : targetProxy.y + targetProxy.height)
            width: root.vertical ? root._wrapDepth : root._cornerSize
            height: root.vertical ? root._cornerSize : root._wrapDepth
            radius: root.vertical
                ? Math.max(root._cornerSize, root._wrapDepth)
                : root._cornerSize
            corner: root.vertical ? "topRight" : "topLeft"
            transform: Scale {
                origin.x: (root.vertical ? root._wrapDepth : root._cornerSize) / 2
                origin.y: (root.vertical ? root._cornerSize : root._wrapDepth) / 2
                yScale: !root.vertical && root.edge === "bottom" ? -1 : 1
            }
            color: Theme.debugBarSilhouette ? Qt.rgba(1.0, 0.2, 0.2, 0.65) : "white"
            visible: root.hasWrap && !root.vertical && !root.bottomLeftRounded
                && width > 0 && height > 0
        }

        NotchCornerMask {
            x: root.vertical ? (root.edge === "left" ? targetProxy.x + targetProxy.width : targetProxy.x - root._wrapDepth) : targetProxy.x + targetProxy.width - width
            y: root.vertical ? targetProxy.y + targetProxy.height - height : (root.edge === "bottom" ? targetProxy.y - root._wrapDepth : targetProxy.y + targetProxy.height)
            width: root.vertical ? root._wrapDepth : root._cornerSize
            height: root.vertical ? root._cornerSize : root._wrapDepth
            radius: root.vertical
                ? Math.max(root._cornerSize, root._wrapDepth)
                : root._cornerSize
            corner: root.vertical ? (root.edge === "left" ? "bottomLeft" : "bottomRight") : "topRight"
            transform: Scale {
                origin.x: (root.vertical ? root._wrapDepth : root._cornerSize) / 2
                origin.y: (root.vertical ? root._cornerSize : root._wrapDepth) / 2
                yScale: !root.vertical && root.edge === "bottom" ? -1 : 1
            }
            color: Theme.debugBarSilhouette ? Qt.rgba(1.0, 0.2, 0.2, 0.65) : "white"
            visible: root.hasWrap && !root.vertical && !root.bottomRightRounded
                && width > 0 && height > 0
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
