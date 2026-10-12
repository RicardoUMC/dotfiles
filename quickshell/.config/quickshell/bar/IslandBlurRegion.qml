import QtQuick
import Quickshell
import "."

// Fixed composition of one BarSection's interactive silhouette.
// This remains independent from the authoritative Canvas/MultiEffect mask and
// input region: native blur accepts a QRegion, with bounded lower wrap-corner
// approximations for the decorative side curves.
Region {
    id: root

    required property BarSection targetItem
    // Injected by Bar.qml so each screen independently opts into the pilot.
    // The default is fail-closed and preserves the visible fallback.
    property bool nativeBlurEnabled: false

    readonly property real targetHeight: Math.max(0,
        Number(targetItem.targetItem.height || 0))
    readonly property real corner: Math.max(0, Math.min(
        Number(targetItem._cornerSize || 0), targetHeight))
    readonly property bool leftCornerEnabled: targetItem.leftCornerEnabled
    readonly property bool rightCornerEnabled: targetItem.rightCornerEnabled
    // BarSection is the coordinate origin for the direct Region composition.
    readonly property real sectionX: Number(targetItem.x || 0)
    readonly property real sectionY: Number(targetItem.y || 0)
    readonly property real sectionWidth: Math.max(0, Number(targetItem.width || 0))
    readonly property real leftExtent: leftCornerEnabled ? corner : 0
    readonly property real bodyWidth: Math.max(0,
        Number(targetItem.targetItem.width || 0))
    readonly property real wrapDepth: Math.max(0, Number(targetItem._wrapDepth || 0))
    readonly property bool leftWrapEnabled: targetItem.hasWrap
        && !targetItem.bottomLeftRounded && root.corner > 0 && root.wrapDepth > 0
    readonly property bool rightWrapEnabled: targetItem.hasWrap
        && !targetItem.bottomRightRounded && root.corner > 0 && root.wrapDepth > 0

    // The body starts after the left notch cap. Its top edge is completed by
    // the caps below; only BarSection's bottom rounding is carried here.
    Region {
        id: body
        x: root.sectionX + root.leftExtent
        y: root.sectionY
        width: root.bodyWidth
        height: root.targetHeight
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.targetItem.bottomLeftRounded ? root.corner : 0
        bottomRightRadius: root.targetItem.bottomRightRounded ? root.corner : 0
    }

    // Each cap owns its own subtractive disk. Nesting the cutout prevents the
    // disk's negative-x/positive-x half from subtracting the central body.
    Region {
        id: leftCap
        x: root.sectionX
        y: root.sectionY
        width: root.leftCornerEnabled ? root.corner : 0
        height: root.leftCornerEnabled ? root.corner : 0

        Region {
            x: root.sectionX - root.corner
            y: root.sectionY
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    Region {
        id: rightCap
        x: root.sectionX + root.sectionWidth - root.corner
        y: root.sectionY
        width: root.rightCornerEnabled ? root.corner : 0
        height: root.rightCornerEnabled ? root.corner : 0

        Region {
            x: root.sectionX + root.sectionWidth - root.corner
            y: root.sectionY
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    // These fixed corner compositions mirror BarSection's lower lateral wrap
    // masks: a rectangle with the matching circle quadrant removed.
    Region {
        id: leftWrap
        x: root.sectionX + root.leftExtent
        y: root.sectionY + root.targetHeight
        width: root.leftWrapEnabled ? root.corner : 0
        height: root.leftWrapEnabled ? root.wrapDepth : 0

        Region {
            x: root.sectionX + root.leftExtent
            y: root.sectionY + root.targetHeight
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    Region {
        id: rightWrap
        x: root.sectionX + root.leftExtent + root.bodyWidth - root.corner
        y: root.sectionY + root.targetHeight
        width: root.rightWrapEnabled ? root.corner : 0
        height: root.rightWrapEnabled ? root.wrapDepth : 0

        Region {
            x: root.sectionX + root.leftExtent + root.bodyWidth - root.corner * 2
            y: root.sectionY + root.targetHeight
            width: root.corner * 2
            height: root.corner * 2
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    // Keep this opt-in path fail-closed: disabled islands attach no geometry.
    regions: root.nativeBlurEnabled
        ? [body, leftCap, rightCap, leftWrap, rightWrap]
        : []
}
