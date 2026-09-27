import QtQuick

Item {
    id: notchCornerMask

    property string corner: "topLeft"
    property color color: "white"
    property real radius: Math.min(width, height)

    onCornerChanged: cornerCanvas.requestPaint()
    onColorChanged: cornerCanvas.requestPaint()
    onRadiusChanged: cornerCanvas.requestPaint()
    onWidthChanged: cornerCanvas.requestPaint()
    onHeightChanged: cornerCanvas.requestPaint()

    Canvas {
        id: cornerCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            const r = Math.max(0, notchCornerMask.radius);

            ctx.clearRect(0, 0, width, height);
            if (r <= 0) return;

            ctx.beginPath();
            switch (notchCornerMask.corner) {
            case "topRight":
                ctx.arc(0, r, r, 3 * Math.PI / 2, 2 * Math.PI);
                ctx.lineTo(r, 0);
                break;
            case "bottomLeft":
                ctx.arc(r, 0, r, Math.PI / 2, Math.PI);
                ctx.lineTo(0, r);
                break;
            case "bottomRight":
                ctx.arc(0, 0, r, 0, Math.PI / 2);
                ctx.lineTo(r, r);
                break;
            case "topLeft":
            default:
                ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2);
                ctx.lineTo(0, 0);
                break;
            }
            ctx.closePath();
            ctx.fillStyle = notchCornerMask.color;
            ctx.fill();
        }
    }
}
