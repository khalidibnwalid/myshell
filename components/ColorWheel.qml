import "../config/"
import QtQuick
import QtQuick.Layouts

// A colour picker that sits in a panel: a hue and saturation wheel, a brightness bar and a hex field.
// `color` is the colour shown (its opacity is kept); edited(c) is sent as the user changes it.
ColumnLayout {
    id: root

    property color color: "#000000"
    property real hue: 0
    property real sat: 0
    property real val: 1
    property int wheelSize: 150

    signal edited(color c)

    function load(c) {
        const x = Qt.color(String(c));
        if (x.hsvHue >= 0)
            hue = x.hsvHue;
        sat = x.hsvSaturation;
        val = x.hsvValue;
    }

    function emitColor() {
        const c = Qt.hsva(hue, sat, val, color.a);
        edited(c);
    }

    function hexOf(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return (h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }

    function parseHex(text) {
        let t = String(text).trim().replace(/^#/, "");
        if (/^[0-9a-f]{3}$/i.test(t))
            t = t.split("").map(ch => ch + ch).join("");
        return /^[0-9a-f]{6}$/i.test(t) ? Qt.color("#" + t) : null;
    }

    spacing: 8
    // an outside change (palette, picker, swap) moves the wheel; our own edit does not
    onColorChanged: {
        const cur = Qt.hsva(hue, sat, val, 1);
        if (Math.abs(cur.r - color.r) > 0.006 || Math.abs(cur.g - color.g) > 0.006 || Math.abs(cur.b - color.b) > 0.006)
            load(color);
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.wheelSize
        Layout.preferredHeight: root.wheelSize

        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const r = width / 2;
                const g = ctx.createConicalGradient(r, r, 0);
                for (let i = 0; i <= 12; i++)
                    g.addColorStop(i / 12, Qt.hsva((i % 12) / 12, 1, 1, 1));
                ctx.beginPath();
                ctx.arc(r, r, r - 1, 0, Math.PI * 2);
                ctx.fillStyle = g;
                ctx.fill();
                const w = ctx.createRadialGradient(r, r, 0, r, r, r - 1);
                w.addColorStop(0, "rgba(255,255,255,1)");
                w.addColorStop(1, "rgba(255,255,255,0)");
                ctx.beginPath();
                ctx.arc(r, r, r - 1, 0, Math.PI * 2);
                ctx.fillStyle = w;
                ctx.fill();
            }
        }

        // brightness darkens the whole wheel
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: width / 2
            color: "black"
            opacity: 1 - root.val
        }

        Rectangle {
            readonly property real a: root.hue * Math.PI * 2
            readonly property real r: parent.width / 2 - 1

            x: parent.width / 2 + Math.cos(a) * r * root.sat - width / 2
            y: parent.height / 2 - Math.sin(a) * r * root.sat - height / 2
            width: 14
            height: 14
            radius: 7
            color: Qt.hsva(root.hue, root.sat, root.val, 1)
            border.width: 2
            border.color: "white"

            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: "#80000000"
            }
        }

        MouseArea {
            function pick(m) {
                const r = width / 2, dx = m.x - r, dy = r - m.y;
                root.sat = Math.min(1, Math.hypot(dx, dy) / (r - 1));
                if (root.sat > 0.001)
                    root.hue = (Math.atan2(dy, dx) / (Math.PI * 2) + 1) % 1;
                root.emitColor();
            }

            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onPressed: mouse => pick(mouse)
            onPositionChanged: mouse => {
                if (pressed)
                    pick(mouse);
            }
        }
    }

    PillSlider {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        icon: "brightness_6"
        value: root.val
        onDragged: v => {
            root.val = v;
            root.emitColor();
        }
    }

    FieldInput {
        Layout.fillWidth: true
        icon: "tag"
        value: root.hexOf(root.color)
        onCommitted: text => {
            const c = root.parseHex(text);
            if (c) {
                root.load(c);
                root.emitColor();
            } else {
                reset();
            }
        }
    }
}
