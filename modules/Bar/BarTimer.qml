import "../../components/"
import "../../config/"
import "../../services" as Services
import "../../apps/Timer"
import QtQuick

// Shown in the bar only while a countdown of the Timer app runs (or is paused): a capsule with the time
// left of the one that ends first, and how many more there are. A click opens Timer.
Rectangle {
    id: root

    readonly property bool horizontal: Config.barHorizontal
    readonly property bool appOn: Services.Apps.isEnabled("timer")
    // countdowns that are not done yet, the soonest end first (a paused one counts by its time left)
    readonly property var pending: appOn ? Timers.timers.filter(t => t.state === "running" || t.state === "paused").sort((a, b) => root.leftOf(a) - root.leftOf(b)) : []
    readonly property var first: pending.length > 0 ? pending[0] : null
    readonly property bool paused: first !== null && first.state === "paused"
    property double now: Date.now()

    function leftOf(t) {
        return t.state === "running" ? Math.max(0, (t.endAt - now) / 1000) : t.left;
    }

    visible: first !== null
    implicitWidth: horizontal ? row.implicitWidth + 22 : 36
    implicitHeight: horizontal ? 32 : col.implicitHeight + 18
    radius: 18
    color: area.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor
    scale: area.pressed ? 0.94 : 1
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            Services.Apps.open("timer");
            event.accepted = true;
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Timer, " + time.text + " left" + (paused ? ", paused" : "")

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animFast
        }
    }

    // the time moves once a second, only while a countdown runs
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible && root.pending.some(t => t.state === "running")
        onTriggered: root.now = Date.now()
    }

    component Glyph: MaterialSymbol {
        icon: root.paused ? "pause" : "timer"
        fill: 1
        font.pixelSize: 16
        color: root.paused ? Appearance.mutedColor : Appearance.accentColor
    }

    component Time: StyledText {
        // seconds are rounded up, so 0:00 is only shown when it rings
        text: root.first ? Timers.format(Math.ceil(root.leftOf(root.first))) : ""
        font.pixelSize: 11
        font.weight: Font.Bold
        color: root.paused ? Appearance.mutedColor : Appearance.fgColor
        font.features: {
            "tnum": 1
        }
    }

    component More: StyledText {
        visible: root.pending.length > 1
        text: "+" + (root.pending.length - 1)
        font.pixelSize: 10
        color: Appearance.mutedColor
    }

    // a top or bottom bar: icon, time and the count side by side
    Row {
        id: row

        visible: root.horizontal
        anchors.centerIn: parent
        spacing: 5

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
        }

        Time {
            anchors.verticalCenter: parent.verticalCenter
        }

        More {
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // a side bar: icon over the time
    Column {
        id: col

        visible: !root.horizontal
        anchors.centerIn: parent
        spacing: 2

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Time {
            id: time

            anchors.horizontalCenter: parent.horizontalCenter
        }

        More {
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    FocusRing {
        radius: root.radius
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.Apps.open("timer")
    }
}
