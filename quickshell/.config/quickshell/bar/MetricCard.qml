import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property real value: 0
    property var history: []
    property color color: Colors.accent
    property bool disabled: false

    readonly property real progress: disabled ? 0 : Math.max(0, Math.min(100, value)) / 100
    readonly property color activeColor: disabled ? Colors.muted : color

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.dashboardCardHeight

    onHistoryChanged: sparkCanvas.requestPaint()
    onDisabledChanged: sparkCanvas.requestPaint()
    onColorChanged: sparkCanvas.requestPaint()
    onWidthChanged: sparkCanvas.requestPaint()
    onHeightChanged: sparkCanvas.requestPaint()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacitySurface)
        border {
            width: 1
            color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, Theme.opacityBorder)
        }

        RowLayout {
            anchors { fill: parent; margins: Theme.spacingXs }
            spacing: Theme.spacingSm

            Text {
                text: root.icon
                color: root.activeColor
                font { family: Colors.monoFont; pixelSize: Theme.fontSizeBodyLg }
            }

            Text {
                text: root.label
                color: root.disabled ? Colors.muted : Colors.text
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.dashboardProgressHeight
                radius: Theme.dashboardProgressRadius
                color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: root.activeColor

                    Behavior on width {
                        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
                    }
                }
            }

            Canvas {
                id: sparkCanvas
                Layout.preferredWidth: Theme.dashboardSparklineWidth
                Layout.preferredHeight: Theme.dashboardSparklineHeight
                antialiasing: true
                opacity: root.disabled ? 0.45 : 1

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    if (root.disabled || !root.history || root.history.length < 2)
                        return

                    const xStep = width / (root.systemMaxSamples() - 1)
                    ctx.beginPath()

                    for (let i = 0; i < root.history.length; i++) {
                        const sample = Math.max(0, Math.min(100, root.history[i]))
                        const x = i * xStep
                        const y = height - (sample / 100) * height

                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }

                    ctx.strokeStyle = root.activeColor
                    ctx.lineWidth = 1
                    ctx.stroke()

                    const grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.25))
                    grad.addColorStop(1, Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.0))
                    ctx.lineTo((root.history.length - 1) * xStep, height)
                    ctx.lineTo(0, height)
                    ctx.closePath()
                    ctx.fillStyle = grad
                    ctx.fill()
                }
            }

            Text {
                Layout.preferredWidth: 36
                text: root.disabled ? "N/A" : Math.round(root.value) + "%"
                color: root.activeColor
                horizontalAlignment: Text.AlignRight
                font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
            }
        }
    }

    function systemMaxSamples() {
        return 32
    }
}
