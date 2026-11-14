import "../config/"
import "../services/"
import QtQuick

// The displays drawn to scale, like the arrangement view of other settings apps:
// click one to pick it, drag one to place it next to the others.
Item {
    id: root

    property var monitors: []
    property string selected: ""

    signal picked(string name)

    function logical(m) {
        const t = Number((m.lastIpcObject || {}).transform || 0);
        const w = m.width / m.scale;
        const h = m.height / m.scale;
        return t % 2 === 1 ? {
            "w": h,
            "h": w
        } : {
            "w": w,
            "h": h
        };
    }

    // room around the displays so one can be dragged to any side
    readonly property var bounds: {
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9, big = 0;
        for (const m of monitors) {
            const s = logical(m);
            x0 = Math.min(x0, m.x);
            y0 = Math.min(y0, m.y);
            x1 = Math.max(x1, m.x + s.w);
            y1 = Math.max(y1, m.y + s.h);
            big = Math.max(big, s.w, s.h);
        }
        if (monitors.length === 0)
            return {
                "x": 0,
                "y": 0,
                "w": 1920,
                "h": 1080
            };
        const room = monitors.length > 1 ? big * 0.6 : big * 0.2;
        return {
            "x": x0 - room,
            "y": y0 - room * 0.6,
            "w": x1 - x0 + room * 2,
            "h": y1 - y0 + room * 1.2
        };
    }
    readonly property real factor: Math.min(width / bounds.w, height / bounds.h)
    readonly property real offsetX: (width - bounds.w * factor) / 2
    readonly property real offsetY: (height - bounds.h * factor) / 2

    implicitHeight: 210

    Repeater {
        model: root.monitors

        delegate: Rectangle {
            id: tile

            required property var modelData
            required property int index
            readonly property var size: root.logical(modelData)
            readonly property bool current: root.selected === modelData.name
            readonly property color contentColor: current ? Appearance.accentContrastColor : Appearance.fgColor

            function place() {
                x = Qt.binding(() => root.offsetX + (modelData.x - root.bounds.x) * root.factor);
                y = Qt.binding(() => root.offsetY + (modelData.y - root.bounds.y) * root.factor);
            }

            width: size.w * root.factor - 3
            height: size.h * root.factor - 3
            radius: 12
            color: current ? Appearance.accentColor : (area.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
            border.width: 2
            border.color: current ? Appearance.accentColor : Appearance.outlineColor
            z: area.drag.active ? 10 : 0
            Component.onCompleted: place()

            Column {
                anchors.centerIn: parent
                spacing: 2

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.index + 1
                    font.pixelSize: Math.max(16, Math.min(34, tile.height * 0.32))
                    font.weight: Font.Light
                    color: tile.contentColor
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, tile.width - 12)
                    visible: tile.height > 70
                    text: tile.modelData.name
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: tile.contentColor
                    opacity: 0.75
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                drag.target: root.monitors.length > 1 ? tile : null
                onPressed: root.picked(tile.modelData.name)
                onReleased: {
                    if (root.monitors.length > 1 && drag.active) {
                        const lx = (tile.x - root.offsetX) / root.factor + root.bounds.x;
                        const ly = (tile.y - root.offsetY) / root.factor + root.bounds.y;
                        const spot = Displays.snap(tile.modelData, lx, ly, root.monitors);
                        Displays.move(tile.modelData, spot.x, spot.y);
                    }
                    tile.place();
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animFast
                }
            }
        }
    }
}
