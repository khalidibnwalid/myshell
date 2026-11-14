import "../config/"
import QtQuick

// A circular level gauge with a number in the middle and a caption below.
Item {
    id: root

    property real value: 0
    property string icon
    property string valueText
    property string label
    property string detail
    property color color: Appearance.accentColor

    implicitWidth: 150
    implicitHeight: ring.height + 8 + captions.implicitHeight

    Item {
        id: ring

        width: Math.min(parent.width, 120)
        height: width
        anchors.horizontalCenter: parent.horizontalCenter

        property real shown: Math.max(0, Math.min(1, root.value))

        Behavior on shown {
            NumberAnimation {
                duration: Appearance.animSlow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeOut
            }
        }

        onShownChanged: canvas.requestPaint()

        Canvas {
            id: canvas

            anchors.fill: parent
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = 11;
                const r = (width - w) / 2;
                const cx = width / 2;
                const start = Math.PI * 0.75;
                const span = Math.PI * 1.5;
                ctx.lineWidth = w;
                ctx.lineCap = "round";
                ctx.strokeStyle = Appearance.surfaceHighColor;
                ctx.beginPath();
                ctx.arc(cx, cx, r, start, start + span);
                ctx.stroke();
                if (ring.shown > 0.005) {
                    ctx.strokeStyle = root.color;
                    ctx.beginPath();
                    ctx.arc(cx, cx, r, start, start + span * ring.shown);
                    ctx.stroke();
                }
            }
            Connections {
                target: Appearance
                function onAccentColorChanged() { canvas.requestPaint(); }
                function onFgColorChanged() { canvas.requestPaint(); }
            }
            onWidthChanged: requestPaint()
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.icon
                fill: 1
                font.pixelSize: 20
                color: root.color
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.valueText
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
        }
    }

    Column {
        id: captions

        anchors.top: ring.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 1

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.label
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: root.detail
            color: Appearance.mutedColor
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
