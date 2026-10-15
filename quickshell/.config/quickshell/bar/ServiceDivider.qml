import QtQuick
import QtQuick.Layouts
import "../theme"

// Passive service/power separator. The arc bends toward the monitor interior
// so it reads as part of the island silhouette rather than a pasted rectangle.
Item {
    id: root

    property bool vertical: false
    property string edge: "top"
    property string mode: "arc"

    readonly property bool dividerEnabled: root.mode !== "none" && Theme.islandSeparatorWidth > 0
    readonly property real crossSize: Math.max(1, Theme.barChipHeight - Theme.spacingSm)
    readonly property real longitudinalSize: root.dividerEnabled
        ? Math.max(12, Theme.islandSemanticGap * 2 + Math.max(Theme.islandSeparatorWidth, 1))
        : 0
    readonly property real bend: Math.max(2, Math.min(
        Theme.islandSemanticGap,
        (root.vertical ? root.longitudinalSize : root.crossSize) / 2 - 1))

    implicitWidth: root.vertical ? root.crossSize : root.longitudinalSize
    implicitHeight: root.vertical ? root.longitudinalSize : root.crossSize
    width: implicitWidth
    height: implicitHeight
    visible: root.dividerEnabled

    Canvas {
        id: dividerCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!root.dividerEnabled) return

            const stroke = Math.max(1, Number(Theme.islandSeparatorWidth))
            const color = Qt.rgba(Colors.muted.r, Colors.muted.g,
                                  Colors.muted.b, Theme.opacityBorder)
            ctx.beginPath()
            ctx.lineWidth = stroke
            ctx.strokeStyle = color
            ctx.lineCap = "round"

            if (root.vertical) {
                const y = height / 2
                const inward = root.edge === "left" ? 1 : -1
                const controlY = y + inward * root.bend
                if (root.mode === "hairline") {
                    ctx.moveTo(0, y)
                    ctx.lineTo(width, y)
                } else {
                    ctx.moveTo(0, y)
                    ctx.quadraticCurveTo(width / 2, controlY, width, y)
                }
            } else {
                const x = width / 2
                const inward = root.edge === "top" ? 1 : -1
                const controlX = x + inward * root.bend
                if (root.mode === "hairline") {
                    ctx.moveTo(x, 0)
                    ctx.lineTo(x, height)
                } else {
                    ctx.moveTo(x, 0)
                    ctx.quadraticCurveTo(controlX, height / 2, x, height)
                }
            }
            ctx.stroke()
        }
    }

    onDividerEnabledChanged: dividerCanvas.requestPaint()
    onModeChanged: dividerCanvas.requestPaint()
    onEdgeChanged: dividerCanvas.requestPaint()
    onVerticalChanged: dividerCanvas.requestPaint()
    onWidthChanged: dividerCanvas.requestPaint()
    onHeightChanged: dividerCanvas.requestPaint()
}
