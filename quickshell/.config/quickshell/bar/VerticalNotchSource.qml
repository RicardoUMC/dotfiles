import QtQuick

Item {
    id: verticalNotchSource

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
    property color maskColor: "white"

    readonly property real resolvedCornerSize: Math.max(0, cornerSize)

    // Both lateral edges use the canonical horizontal source. It rotates
    // counter-clockwise once, then mirrors the final physical cross-axis for
    // right. Source width/height are the swapped vertical target dimensions;
    // the full visual section includes its wrap depth.
    visible: vertical

    Item {
        id: verticalMirror
        anchors.fill: parent
        transform: Scale {
            origin.x: verticalMirror.width / 2
            origin.y: verticalMirror.height / 2
            xScale: verticalNotchSource.edge === "right" ? -1 : 1
        }

        Item {
            id: rotatedHorizontalSource
            width: verticalNotchSource.height
            height: verticalNotchSource.targetItem.width
                + (verticalNotchSource.hasWrap ? verticalNotchSource.wrapDepth : 0)
            anchors.centerIn: parent
            layer.enabled: verticalNotchSource.vertical
                && verticalNotchSource.edge === "right"
                && (verticalNotchSource.sectionId === "center"
                    || verticalNotchSource.sectionId === "right")
            layer.smooth: true
            transform: Rotation { angle: -90; origin.x: rotatedHorizontalSource.width / 2; origin.y: rotatedHorizontalSource.height / 2 }

            // This is the canonical horizontal top grammar. The source is
            // rotated as one whole source (CCW): (u,v) -> (v,W-u), where W is
            // this source's width. The outer mirror makes right the physical
            // counterpart without changing section-specific endpoint flags.
            NotchCornerMask {
                id: leftSourceCap
                x: 0
                y: 0
                width: verticalNotchSource.leftCornerEnabled ? verticalNotchSource.resolvedCornerSize : 0
                height: width
                // Match the canonical horizontal source: the source-left cap's
                // rounded side faces the body attachment, not the remote tip.
                corner: "topRight"
                color: verticalNotchSource.maskColor
                visible: width > 0
            }

            Rectangle {
                x: leftSourceCap.width
                y: 0
                width: verticalNotchSource.targetItem.height
                height: verticalNotchSource.targetItem.width
                color: verticalNotchSource.maskColor
                bottomLeftRadius: verticalNotchSource.bottomLeftRounded ? verticalNotchSource.resolvedCornerSize : 0
                bottomRightRadius: verticalNotchSource.bottomRightRounded ? verticalNotchSource.resolvedCornerSize : 0
            }

            NotchCornerMask {
                id: leftSourceEndCap
                x: (verticalNotchSource.leftCornerEnabled ? verticalNotchSource.resolvedCornerSize : 0)
                    + verticalNotchSource.targetItem.height
                y: 0
                width: verticalNotchSource.rightCornerEnabled ? verticalNotchSource.resolvedCornerSize : 0
                height: width
                // Match the canonical source-right cap; this also fixes the
                // physical lower endpoint after the -90-degree rotation.
                corner: "topLeft"
                color: verticalNotchSource.maskColor
                visible: width > 0
            }

            NotchCornerMask {
                x: leftSourceCap.width
                y: verticalNotchSource.targetItem.width
                width: verticalNotchSource.vertical
                    ? verticalNotchSource.wrapRadius : verticalNotchSource.resolvedCornerSize
                height: verticalNotchSource.vertical && verticalNotchSource.hasWrap
                    ? verticalNotchSource.wrapDepth : 0
                radius: verticalNotchSource.vertical
                    ? Math.max(verticalNotchSource.resolvedCornerSize,
                              verticalNotchSource.wrapDepth,
                              verticalNotchSource.wrapRadius)
                    : verticalNotchSource.resolvedCornerSize
                // Keep the horizontal left-end corner in the checkpoint source;
                // the remaining lower-end refinement is tracked separately.
                corner: "topLeft"
                color: verticalNotchSource.maskColor
                visible: verticalNotchSource.hasWrap
                    && verticalNotchSource.bottomLeftRounded === false
                    && width > 0 && height > 0
            }

            NotchCornerMask {
                x: leftSourceCap.width + verticalNotchSource.targetItem.height - width
                y: verticalNotchSource.targetItem.width
                width: verticalNotchSource.vertical
                    ? verticalNotchSource.wrapRadius : verticalNotchSource.resolvedCornerSize
                height: verticalNotchSource.vertical && verticalNotchSource.hasWrap
                    ? verticalNotchSource.wrapDepth : 0
                radius: verticalNotchSource.vertical
                    ? Math.max(verticalNotchSource.resolvedCornerSize,
                              verticalNotchSource.wrapDepth,
                              verticalNotchSource.wrapRadius)
                    : verticalNotchSource.resolvedCornerSize
                // Source-right becomes the physical upper endpoint after the
                // -90-degree mapping, so preserve the horizontal right-end cap.
                corner: verticalNotchSource.vertical ? "topRight" : "topLeft"
                color: verticalNotchSource.maskColor
                visible: verticalNotchSource.hasWrap
                    && verticalNotchSource.bottomRightRounded === false
                    && width > 0 && height > 0
            }
        }
    }
}
