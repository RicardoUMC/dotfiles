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
    readonly property real corner: Math.max(0, Number(targetItem._cornerSize || 0))
    readonly property bool leftCornerEnabled: targetItem.leftCornerEnabled
    readonly property bool rightCornerEnabled: targetItem.rightCornerEnabled
    readonly property real sectionX: Number(targetItem.x || 0)
    readonly property real sectionY: Number(targetItem.y || 0)
    readonly property real sectionWidth: Math.max(0, Number(targetItem.width || 0))
    readonly property real sectionHeight: Math.max(0, Number(targetItem.height || 0))
    readonly property bool bottom: !targetItem.vertical && targetItem.edge === "bottom"
    readonly property bool left: targetItem.vertical && targetItem.edge === "left"
    readonly property bool right: targetItem.vertical && targetItem.edge === "right"
    readonly property real wrapDepth: Math.max(0, Number(targetItem._wrapDepth || 0))
    readonly property real targetY: root.sectionY + targetItem._targetYFromSection
    readonly property real leftExtent: targetItem._leftExtent
    readonly property real rightExtent: targetItem._rightExtent
    readonly property real bodyWidth: Math.max(0,
        Number(targetItem.targetItem.width || 0))
    readonly property bool leftWrapEnabled: targetItem._leftWrapEnabled
    readonly property bool rightWrapEnabled: targetItem._rightWrapEnabled
    readonly property real leftSourceWidth: targetItem._horizontalSourceWidth
    readonly property real leftSourceHeight: targetItem._horizontalSourceHeight

    // Left uses the same horizontal source as the visible mask. For a source
    // rectangle (u,v,w,h), CCW screen rotation maps it to
    // (x,y,w',h') = (v,W-u-w,h,w), relative to the section root.
    Region {
        id: leftBody
        x: root.sectionX
        y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.targetHeight
        width: root.bodyWidth
        height: root.targetHeight
        topLeftRadius: 0
        topRightRadius: root.targetItem.bottomRightRounded ? root.corner : 0
        bottomLeftRadius: 0
        bottomRightRadius: root.targetItem.bottomLeftRounded ? root.corner : 0
    }
    Region {
        id: leftCap
        x: root.sectionX
        y: root.sectionY + root.leftSourceWidth - root.leftExtent
        width: root.corner
        height: root.leftExtent
        Region {
            x: root.sectionX
            y: root.sectionY + root.leftSourceWidth - root.corner
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: leftRightCap
        x: root.sectionX
        y: root.sectionY
        width: root.corner
        height: root.rightExtent
        Region {
            x: root.sectionX
            y: root.sectionY - root.corner
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: leftWrap
        x: root.sectionX + root.bodyWidth
        y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.corner
        width: root.wrapDepth
        height: root.leftWrapEnabled ? root.corner : 0
        Region {
            x: root.sectionX + root.bodyWidth
            y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.corner * 2
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: leftRightWrap
        x: root.sectionX + root.bodyWidth
        y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.targetHeight
        width: root.wrapDepth
        height: root.rightWrapEnabled ? root.corner : 0
        Region {
            x: root.sectionX + root.bodyWidth
            y: root.sectionY + root.rightExtent
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    // The pre-existing manual vertical-right composition remains separate.
    Region {
        id: rightBody
        x: root.sectionX
        y: root.targetY
        width: root.bodyWidth
        height: root.targetHeight
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.targetItem.bottomLeftRounded ? root.corner : 0
        bottomRightRadius: root.targetItem.bottomRightRounded ? root.corner : 0
    }
    Region { id: rightCapVertical; x: root.sectionX; y: root.targetY + root.targetHeight; width: root.bodyWidth; height: root.rightExtent
        Region { x: root.sectionX + root.sectionWidth - root.corner; y: root.targetY + root.targetHeight - root.corner * 2; width: root.corner * 2; height: root.corner * 2; shape: RegionShape.Ellipse; intersection: Intersection.Subtract } }
    Region { id: rightLeftCapVertical; x: root.sectionX; y: root.sectionY; width: root.bodyWidth; height: root.leftExtent
        Region { x: root.sectionX - root.corner; y: root.sectionY; width: root.corner * 2; height: root.corner * 2; shape: RegionShape.Ellipse; intersection: Intersection.Subtract } }
    Region { id: rightWrapVertical; x: root.sectionX + root.bodyWidth; y: root.targetY; width: root.wrapDepth; height: root.leftExtent
        Region { x: root.sectionX + root.leftExtent; y: root.sectionY + root.targetHeight; width: root.corner * 2; height: root.corner * 2; shape: RegionShape.Ellipse; intersection: Intersection.Subtract } }
    Region { id: rightRightWrapVertical; x: root.sectionX + root.bodyWidth; y: root.targetY + root.targetHeight - root.rightExtent; width: root.wrapDepth; height: root.rightExtent
        Region { x: root.sectionX + root.leftExtent + root.bodyWidth - root.corner * 2; y: root.sectionY + root.targetHeight; width: root.corner * 2; height: root.corner * 2; shape: RegionShape.Ellipse; intersection: Intersection.Subtract } }

    // Existing horizontal top/bottom composition is retained.
    Region {
        id: body
        x: root.sectionX + root.leftExtent
        y: root.targetY
        width: root.bodyWidth
        height: root.targetHeight
        topLeftRadius: root.left ? 0 : (root.bottom && root.targetItem.bottomLeftRounded ? root.corner : 0)
        topRightRadius: root.left ? 0 : (root.bottom && root.targetItem.bottomRightRounded ? root.corner : 0)
        bottomLeftRadius: root.left ? 0 : (root.bottom ? 0 : (root.targetItem.bottomLeftRounded ? root.corner : 0))
        bottomRightRadius: root.left ? 0 : (root.bottom ? 0 : (root.targetItem.bottomRightRounded ? root.corner : 0))
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
        id: normalLeftCap
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
        id: leftWrapNormal
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
        ? (root.left ? [leftBody, leftCap, leftRightCap, leftWrap, leftRightWrap]
            : (root.right ? [rightBody, rightCapVertical, rightLeftCapVertical, rightWrapVertical, rightRightWrapVertical]
                : [body, normalLeftCap, rightCap, leftWrapNormal, rightWrap]))
        : []
}
