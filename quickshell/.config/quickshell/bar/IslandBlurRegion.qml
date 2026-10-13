import QtQuick
import Quickshell
import "."

// Fixed composition of one BarSection's interactive silhouette.
// This remains independent from the authoritative Canvas/MultiEffect mask and
// input region: native blur accepts a QRegion.
Region {
    id: root

    required property BarSection targetItem
    property bool nativeBlurEnabled: false

    readonly property real targetHeight: Math.max(0,
        Number(targetItem.targetItem.height || 0))
    readonly property real corner: Math.max(0, Math.min(
        Number(targetItem._cornerSize || 0), targetHeight))
    readonly property bool leftCornerEnabled: targetItem.leftCornerEnabled
    readonly property bool rightCornerEnabled: targetItem.rightCornerEnabled
    readonly property real sectionX: Number(targetItem.x || 0)
    readonly property real sectionY: Number(targetItem.y || 0)
    readonly property real sectionWidth: Math.max(0, Number(targetItem.width || 0))
    readonly property bool bottom: !targetItem.vertical && targetItem.edge === "bottom"
    readonly property real wrapDepth: Math.max(0, Number(targetItem._wrapDepth || 0))
    readonly property real targetY: root.sectionY + (root.bottom ? root.wrapDepth : 0)
    readonly property real leftExtent: leftCornerEnabled ? corner : 0
    readonly property real bodyWidth: Math.max(0,
        Number(targetItem.targetItem.width || 0))
    readonly property bool leftWrapEnabled: targetItem.hasWrap
        && !targetItem.bottomLeftRounded && root.corner > 0 && root.wrapDepth > 0
    readonly property bool rightWrapEnabled: targetItem.hasWrap
        && !targetItem.bottomRightRounded && root.corner > 0 && root.wrapDepth > 0

    // Top remains the original composition. Bottom reflects the body,
    // notch caps, and decorative wraps across the horizontal axis.
    Region {
        id: body
        x: root.sectionX + root.leftExtent
        y: root.targetY
        width: root.bodyWidth
        height: root.targetHeight
        topLeftRadius: root.bottom && root.targetItem.bottomLeftRounded ? root.corner : 0
        topRightRadius: root.bottom && root.targetItem.bottomRightRounded ? root.corner : 0
        bottomLeftRadius: root.bottom ? 0 : (root.targetItem.bottomLeftRounded ? root.corner : 0)
        bottomRightRadius: root.bottom ? 0 : (root.targetItem.bottomRightRounded ? root.corner : 0)
    }

    Region {
        id: leftCap
        x: root.sectionX
        y: root.bottom ? root.targetY + root.targetHeight - root.corner : root.sectionY
        width: root.leftCornerEnabled ? root.corner : 0
        height: root.leftCornerEnabled ? root.corner : 0

        Region {
            x: root.sectionX - root.corner
            y: root.bottom ? root.targetY + root.targetHeight - root.corner * 2 : root.sectionY
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    Region {
        id: rightCap
        x: root.sectionX + root.sectionWidth - root.corner
        y: root.bottom ? root.targetY + root.targetHeight - root.corner : root.sectionY
        width: root.rightCornerEnabled ? root.corner : 0
        height: root.rightCornerEnabled ? root.corner : 0

        Region {
            x: root.sectionX + root.sectionWidth - root.corner
            y: root.bottom ? root.targetY + root.targetHeight - root.corner * 2 : root.sectionY
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    Region {
        id: leftWrap
        x: root.sectionX + root.leftExtent
        y: root.bottom ? root.sectionY : root.sectionY + root.targetHeight
        width: root.leftWrapEnabled ? root.corner : 0
        height: root.leftWrapEnabled ? root.wrapDepth : 0

        Region {
            x: root.sectionX + root.leftExtent
            y: root.bottom ? root.sectionY + root.wrapDepth - root.corner * 2 : root.sectionY + root.targetHeight
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    Region {
        id: rightWrap
        x: root.sectionX + root.leftExtent + root.bodyWidth - root.corner
        y: root.bottom ? root.sectionY : root.sectionY + root.targetHeight
        width: root.rightWrapEnabled ? root.corner : 0
        height: root.rightWrapEnabled ? root.wrapDepth : 0

        Region {
            x: root.sectionX + root.leftExtent + root.bodyWidth - root.corner * 2
            y: root.bottom ? root.sectionY + root.wrapDepth - root.corner * 2 : root.sectionY + root.targetHeight
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    regions: root.nativeBlurEnabled
        ? [body, leftCap, rightCap, leftWrap, rightWrap]
        : []
}
