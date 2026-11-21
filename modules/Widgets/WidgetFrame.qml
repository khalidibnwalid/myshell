import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick

// One widget on the desktop: the glass panel, the content of its type, and, while editing, the
// outline, the drag and the small toolbar (smaller, bigger, other look, remove).
Item {
    id: frame

    required property string wid
    // the area it can move in
    required property Item host

    readonly property var cfg: DesktopWidgets.items.find(i => i.id === wid) ?? ({})
    readonly property bool editing: DesktopWidgets.editing
    readonly property var info: DesktopWidgets.typeInfo(cfg.type ?? "")
    readonly property real u: cfg.scale ?? 1
    // what this widget looks like; a key it does not set is the theme's default
    readonly property var look: {
        const out = {
            "fg": cfg.color ? cfg.color : Appearance.fgColor,
            "accent": cfg.accent ? cfg.accent : Appearance.accentColor,
            "shadow": DesktopWidgets.shadowLevels[cfg.shadow ?? "soft"] ?? 1
        };
        if (cfg.barWidth === "thin")
            out.barFill = 0.3;
        else if (cfg.barWidth === "thick")
            out.barFill = 0.95;
        if (cfg.numerals === "arabic")
            out.arabic = true;
        const gaps = {
            "overlap": -1,
            "tight": -0.5,
            "wide": 1,
            "wider": 2
        };
        if (cfg.gap)
            out.gap = gaps[cfg.gap] ?? 0;
        if (cfg.digitGap)
            out.digitGap = gaps[cfg.digitGap] ?? 0;
        if (cfg.dateGap)
            out.dateGap = ({
                    "tight": 0.4,
                    "wide": 1.8,
                    "wider": 2.8
                })[cfg.dateGap] ?? 1;
        if (cfg.contrast === "soft")
            out.contrast = 1.0;
        else if (cfg.contrast === "strong")
            out.contrast = 2.6;
        if (cfg.barCount)
            out.barCount = cfg.barCount;
        if (cfg.barShape === "square")
            out.barRound = false;
        if (cfg.pulse === "off")
            out.pulse = false;
        if (cfg.date === "hidden")
            out.hideDate = true;
        if (cfg.font)
            out.family = cfg.font;
        if (cfg.weight !== undefined)
            out.weight = cfg.weight;
        return out;
    }

    opacity: cfg.opacity ?? 1

    width: body.item ? body.item.implicitWidth : 0
    height: body.item ? body.item.implicitHeight : 0
    visible: body.item !== null

    // follow the saved place, except while it is being dragged
    Binding {
        target: frame
        property: "x"
        value: Math.round((frame.cfg.x ?? 0) * frame.host.width)
        when: !drag.drag.active
    }

    Binding {
        target: frame
        property: "y"
        value: Math.round((frame.cfg.y ?? 0) * frame.host.height)
        when: !drag.drag.active
    }

    Loader {
        id: body

        sourceComponent: ({
                "clock": clockComponent,
                "waves": wavesComponent,
                "calendar": calendarComponent
            })[frame.cfg.type ?? ""] ?? null
    }

    Component {
        id: clockComponent

        ClockWidget {
            u: frame.u
            style: frame.cfg.style ?? "stacked"
            look: frame.look
        }
    }

    Component {
        id: wavesComponent

        WavesWidget {
            u: frame.u
            style: frame.cfg.style ?? "bars"
            look: frame.look
        }
    }

    Component {
        id: calendarComponent

        CalendarCard {
            u: frame.u
            look: frame.look
        }
    }

    // --- edit mode ---
    Rectangle {
        visible: frame.editing
        anchors.fill: parent
        anchors.margins: -2
        radius: 18
        color: drag.drag.active ? Qt.alpha(Appearance.accentColor, 0.12) : "transparent"
        border.width: 2
        border.color: Appearance.accentColor
    }

    MouseArea {
        id: drag

        enabled: frame.editing
        anchors.fill: parent
        cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: frame
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: Math.max(0, frame.host.width - frame.width)
        drag.maximumY: Math.max(0, frame.host.height - frame.height)
        // a little pull to the edges and the middle lines makes a tidy layout easy
        drag.threshold: 2
        onReleased: {
            const snap = 14;
            let nx = frame.x;
            let ny = frame.y;
            const w = frame.host.width;
            const h = frame.host.height;
            if (nx < snap)
                nx = 0;
            else if (nx + frame.width > w - snap)
                nx = w - frame.width;
            else if (Math.abs(nx + frame.width / 2 - w / 2) < snap)
                nx = w / 2 - frame.width / 2;
            if (ny < snap)
                ny = 0;
            else if (ny + frame.height > h - snap)
                ny = h - frame.height;
            else if (Math.abs(ny + frame.height / 2 - h / 2) < snap)
                ny = h / 2 - frame.height / 2;
            DesktopWidgets.update(frame.wid, {
                "x": nx / w,
                "y": ny / h
            });
        }
        // the wheel resizes the widget under the pointer
        onWheel: wheel => DesktopWidgets.setScale(frame.wid, frame.u + (wheel.angleDelta.y > 0 ? 0.1 : -0.1))
    }

    Rectangle {
        id: tools

        visible: frame.editing
        // above the widget, or below it when there is no room
        y: frame.y > height + 12 ? -height - 8 : frame.height + 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: toolsRow.implicitWidth + 12
        height: 44
        radius: height / 2
        color: Qt.alpha(Appearance.bgColor, 0.92)
        border.width: 1
        border.color: Appearance.outlineColor

        Row {
            id: toolsRow

            anchors.centerIn: parent
            spacing: 2

            IconButton {
                icon: "remove"
                iconSize: 20
                size: 34
                enabled: frame.u > 0.5
                onClicked: DesktopWidgets.setScale(frame.wid, frame.u - 0.1)
            }

            IconButton {
                icon: "add"
                iconSize: 20
                size: 34
                onClicked: DesktopWidgets.setScale(frame.wid, frame.u + 0.1)
            }

            IconButton {
                icon: "tune"
                iconSize: 20
                size: 34
                toggled: DesktopWidgets.optionsFor === frame.wid
                onClicked: DesktopWidgets.optionsFor = DesktopWidgets.optionsFor === frame.wid ? "" : frame.wid
            }

            IconButton {
                icon: "delete"
                iconSize: 20
                size: 34
                color: "#ff8a80"
                onClicked: {
                    if (DesktopWidgets.optionsFor === frame.wid)
                        DesktopWidgets.optionsFor = "";
                    DesktopWidgets.remove(frame.wid);
                }
            }
        }
    }
}
