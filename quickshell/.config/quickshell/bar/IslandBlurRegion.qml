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
    readonly property bool leftCornerEnabled: targetItem._sourceLeftCornerEnabled
    readonly property bool rightCornerEnabled: targetItem._sourceRightCornerEnabled
    readonly property bool bottomLeftRounded: targetItem._sourceBottomLeftRounded
    readonly property bool bottomRightRounded: targetItem._sourceBottomRightRounded
    readonly property real sectionX: Number(targetItem.x || 0)
    readonly property real sectionY: Number(targetItem.y || 0)
    readonly property real sectionWidth: Math.max(0, Number(targetItem.width || 0))
    readonly property real sectionHeight: Math.max(0, Number(targetItem.height || 0))
    readonly property bool bottom: !targetItem.vertical && targetItem.edge === "bottom"
    readonly property bool left: targetItem.vertical && targetItem.edge === "left"
    readonly property bool right: targetItem.vertical && targetItem.edge === "right"
    readonly property real wrapDepth: Math.max(0, Number(targetItem._wrapDepth || 0))
    readonly property real wrapRadius: Math.max(0,
        Number(targetItem._wrapRadius || targetItem._cornerSize || 0))
    // Horizontal bottom still uses its wrap offset; vertical right uses the
    // physical top extent supplied by the section proxy. Left's rotated source
    // does not consume this value directly, but shares the same frame.
    readonly property real targetY: root.sectionY + targetItem._targetProxyY
    readonly property real leftExtent: targetItem._leftExtent
    readonly property real rightExtent: targetItem._rightExtent
    readonly property real bodyWidth: Math.max(0,
        Number(targetItem.targetItem.width || 0))
    readonly property bool leftWrapEnabled: targetItem._leftWrapEnabled
    readonly property bool rightWrapEnabled: targetItem._rightWrapEnabled
    readonly property real leftSourceWidth: targetItem._horizontalSourceWidth
    readonly property real leftSourceHeight: targetItem._horizontalSourceHeight
    // The rotated visible source uses topLeft/topRight caps for endpoint
    // sections and the mirrored topRight/topLeft pair for the center. Keep
    // native cutouts on the same physical quarter-circle handedness.
    readonly property bool endpointCaps: targetItem.sectionId !== "center"
    readonly property bool lateral: root.left || root.right
    // After CCW rotation, the source-left cap's circle is centered on the
    // physical lower edge. Its ellipse box therefore starts at the cap's
    // parent y, not one radius above it. Keep the horizontal approximation
    // unchanged while correcting only the lateral endpoint.
    readonly property real leftCapCutoutY: root.lateral
        ? root.sectionY + root.leftSourceWidth - root.leftExtent
        : root.sectionY + root.leftSourceWidth
            - (root.endpointCaps ? root.corner * 2 : root.corner)
    // The source-right ellipse remains centered at sectionY after rotation;
    // only its lateral parent rectangle needs to enter the visible frame.
    readonly property real rightCapCutoutY: root.sectionY
        + (root.endpointCaps ? 0 : -root.corner)
    readonly property real sourceRightCapY: root.lateral
        ? root.sectionY + root.rightExtent
        : root.sectionY

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
        topRightRadius: root.bottomRightRounded ? root.corner : 0
        bottomLeftRadius: 0
        bottomRightRadius: root.bottomLeftRounded ? root.corner : 0
    }
    Region {
        id: leftCap
        x: root.sectionX
        y: root.sectionY + root.leftSourceWidth - root.leftExtent
        width: root.corner
        height: root.leftExtent
        Region {
            x: root.sectionX
            y: root.leftCapCutoutY
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: leftRightCap
        x: root.sectionX
        y: root.sourceRightCapY
        width: root.corner
        height: root.rightExtent
        Region {
            x: root.sectionX
            y: root.rightCapCutoutY
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: leftWrap
        x: root.sectionX + root.bodyWidth
        y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.wrapRadius
        width: root.wrapDepth
        height: root.leftWrapEnabled ? root.wrapRadius : 0
        Region {
            x: root.sectionX + root.bodyWidth
            y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.wrapRadius * 2
            width: root.wrapRadius * 2
            height: root.wrapRadius * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: leftRightWrap
        x: root.sectionX + root.bodyWidth
        y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.targetHeight
        width: root.wrapDepth
        height: root.rightWrapEnabled ? root.wrapRadius : 0
        Region {
            x: root.sectionX + root.bodyWidth
            y: root.sectionY + root.rightExtent
            width: root.wrapRadius * 2
            height: root.wrapRadius * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    // Right mirrors the canonical left composition across the vertical
    // section axis. Keep blur and visible masks on the same scalar frame.
    Region {
        id: rightBody
        x: root.sectionX + root.sectionWidth - root.bodyWidth
        y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.targetHeight
        width: root.bodyWidth
        height: root.targetHeight
        topLeftRadius: root.bottomRightRounded ? root.corner : 0
        topRightRadius: 0
        bottomLeftRadius: root.bottomLeftRounded ? root.corner : 0
        bottomRightRadius: 0
    }
    Region {
        id: rightCapVertical
        x: root.sectionX + root.sectionWidth - root.corner
        y: root.sectionY + root.leftSourceWidth - root.leftExtent
        width: root.corner
        height: root.leftExtent
        Region {
            x: root.sectionX + root.sectionWidth - root.corner * 2
            y: root.leftCapCutoutY
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: rightLeftCapVertical
        x: root.sectionX + root.sectionWidth - root.corner
        y: root.sourceRightCapY
        width: root.corner
        height: root.rightExtent
        Region {
            x: root.sectionX + root.sectionWidth - root.corner * 2
            y: root.rightCapCutoutY
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: rightWrapVertical
        x: root.sectionX + root.sectionWidth - root.bodyWidth - root.wrapDepth
        y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.wrapRadius
        width: root.wrapDepth
        height: root.leftWrapEnabled ? root.wrapRadius : 0
        Region {
            x: root.sectionX + root.sectionWidth - root.bodyWidth - root.wrapRadius * 2
            y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.wrapRadius * 2
            width: root.wrapRadius * 2
            height: root.wrapRadius * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }
    Region {
        id: rightRightWrapVertical
        x: root.sectionX + root.sectionWidth - root.bodyWidth - root.wrapDepth
        y: root.sectionY + root.leftSourceWidth - root.leftExtent - root.targetHeight
        width: root.wrapDepth
        height: root.rightWrapEnabled ? root.wrapRadius : 0
        Region {
            x: root.sectionX + root.sectionWidth - root.bodyWidth - root.wrapRadius * 2
            y: root.sectionY + root.rightExtent
            width: root.wrapRadius * 2
            height: root.wrapRadius * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    // Existing horizontal top/bottom composition is retained.
    Region {
        id: body
        x: root.sectionX + root.leftExtent
        y: root.targetY
        width: root.bodyWidth
        height: root.targetHeight
        topLeftRadius: root.left ? 0 : (root.bottom && root.bottomLeftRounded ? root.corner : 0)
        topRightRadius: root.left ? 0 : (root.bottom && root.bottomRightRounded ? root.corner : 0)
        bottomLeftRadius: root.left ? 0 : (root.bottom ? 0 : (root.bottomLeftRounded ? root.corner : 0))
        bottomRightRadius: root.left ? 0 : (root.bottom ? 0 : (root.bottomRightRounded ? root.corner : 0))
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
