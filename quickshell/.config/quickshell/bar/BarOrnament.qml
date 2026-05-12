import QtQuick
import QtQuick.Shapes
import "../theme"

Shape {
    id: root

    readonly property color curveColor: Qt.rgba(
        Colors.accent.r,
        Colors.accent.g,
        Colors.accent.b,
        Theme.ornamentOpacity
    )

    // First arc: sweeps from top-left toward bottom-right
    ShapePath {
        strokeColor: curveColor
        strokeWidth: Theme.ornamentStroke
        fillColor:   "transparent"

        startX: 0
        startY: root.height * 0.3

        PathCubic {
            x:      root.width * 0.6
            y:      root.height * 0.85
            control1X: root.width * 0.15
            control1Y: root.height * 1.1
            control2X: root.width * 0.45
            control2Y: root.height * 0.95
        }
    }

    // Second arc: sweeps from top-right toward bottom-left
    ShapePath {
        strokeColor: curveColor
        strokeWidth: Theme.ornamentStroke
        fillColor:   "transparent"

        startX: root.width
        startY: root.height * 0.2

        PathCubic {
            x:      root.width * 0.35
            y:      root.height * 0.9
            control1X: root.width * 0.85
            control1Y: root.height * 1.0
            control2X: root.width * 0.55
            control2Y: root.height * 0.85
        }
    }
}
