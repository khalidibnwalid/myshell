import "../../config/"
import QtQuick
import Quickshell

// One rounded screen corner of the Inset bar style: a small window at the start or end of the
// bar's inner edge that fills the corner outside a quarter circle with the bar's colour, so the
// desktop looks like a rounded sheet beside the bar. It takes no room and lets clicks through.
PanelWindow {
    id: root

    // false: the start of the bar (top or left), true: its end (bottom or right)
    property bool atEnd: false
    readonly property string position: Config.barPosition
    readonly property int r: Appearance.barCorner
    // the bar's own edge decides which way the shape is mirrored
    readonly property bool mirrorX: position === "left" || (!Config.barHorizontal ? false : !atEnd)
    readonly property bool mirrorY: (position === "right" || position === "left") ? atEnd : (position === "bottom")

    exclusionMode: ExclusionMode.Ignore
    implicitWidth: r
    implicitHeight: r
    color: "transparent"
    // clicks and the pointer pass through to the windows underneath
    mask: Region {}

    anchors {
        top: position === "top" || (!Config.barHorizontal && !atEnd)
        bottom: position === "bottom" || (!Config.barHorizontal && atEnd)
        left: position === "left" || (Config.barHorizontal && !atEnd)
        right: position === "right" || (Config.barHorizontal && atEnd)
    }

    // beside the bar, not under it
    margins {
        top: position === "top" ? Config.barSize : 0
        bottom: position === "bottom" ? Config.barSize : 0
        left: position === "left" ? Config.barSize : 0
        right: position === "right" ? Config.barSize : 0
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            // the shape is drawn for the top-right corner; mirror it for the others
            ctx.translate(root.mirrorX ? width : 0, root.mirrorY ? height : 0);
            ctx.scale(root.mirrorX ? -1 : 1, root.mirrorY ? -1 : 1);
            ctx.fillStyle = Qt.rgba(Appearance.bgColor.r, Appearance.bgColor.g, Appearance.bgColor.b, 1);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width, height);
            ctx.arc(0, height, width, 0, -Math.PI / 2, true);
            ctx.closePath();
            ctx.fill();
            ctx.restore();
        }

        Connections {
            function onBgColorChanged() {
                canvas.requestPaint();
            }

            target: Appearance
        }
    }
}
