import "../../config"
import QtQuick

// A thin ring that empties as the time runs out: value 1 is all of it left, 0 none.
Item {
    id: root

    property real value: 0
    property color trackColor: Appearance.surfaceHighColor
    property color fillColor: Appearance.accentColor
    property real thickness: 5

    onValueChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onFillColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const r = (width - root.thickness) / 2;
            const c = width / 2;
            ctx.lineWidth = root.thickness;
            ctx.lineCap = "round";
            ctx.strokeStyle = root.trackColor;
            ctx.beginPath();
            ctx.arc(c, c, r, 0, Math.PI * 2);
            ctx.stroke();
            if (root.value > 0.004) {
                ctx.strokeStyle = root.fillColor;
                ctx.beginPath();
                ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, root.value));
                ctx.stroke();
            }
        }
    }
}
