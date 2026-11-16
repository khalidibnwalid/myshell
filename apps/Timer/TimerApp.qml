import "../../components"
import "../../config"
import "../../services/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Countdown timers and a stopwatch in their own window. A finished timer rings, with a notification.
// bind = $mainMod, T, global, quickshell:timer
ApplicationWindow {
    id: root

    property string mode: "timer"
    readonly property var presets: [
        {
            "n": "1",
            "unit": "min",
            "seconds": 60
        },
        {
            "n": "5",
            "unit": "min",
            "seconds": 300
        },
        {
            "n": "10",
            "unit": "min",
            "seconds": 600
        },
        {
            "n": "15",
            "unit": "min",
            "seconds": 900
        },
        {
            "n": "25",
            "unit": "min",
            "seconds": 1500
        },
        {
            "n": "30",
            "unit": "min",
            "seconds": 1800
        },
        {
            "n": "45",
            "unit": "min",
            "seconds": 2700
        },
        {
            "n": "1",
            "unit": "hour",
            "seconds": 3600
        }
    ]
    readonly property bool hasDone: Timers.timers.some(t => t.state === "done")

    function openWindow() {
        WindowManager.openTimer();
    }

    // the typed time starts a timer; an unreadable one is told
    function startTyped() {
        const seconds = Timers.parseDuration(timeField.text);
        if (seconds <= 0) {
            hint.text = "Type a time like 5:30, 90, 1h 30m or 45s";
            return;
        }
        hint.text = "";
        Timers.add(seconds, nameField.text.trim());
        timeField.clear();
        nameField.clear();
    }

    width: 480
    height: 640
    minimumWidth: 400
    minimumHeight: 420
    title: "Timer"
    visible: WindowManager.timerVisible
    color: Qt.alpha(Appearance.bgColor, Appearance.isLight ? 1 - Math.pow(1 - Config.appearance.settingsOpacity, 2) : Config.appearance.settingsOpacity)
    onClosing: WindowManager.timerVisible = false
    onVisibleChanged: {
        Timers.watching = visible;
        if (visible)
            Timers.now = Date.now();
    }
    // makes sure the timers are loaded, and a finished one rings, from the start of the shell
    Component.onCompleted: Timers.schedule()

    Connections {
        function onTimerRaiseRequested() {
            root.raise();
            root.requestActivate();
        }

        target: WindowManager
    }

    GlobalShortcut {
        name: "timer"
        onPressed: WindowManager.timerVisible = !WindowManager.timerVisible
    }

    // qs ipc call timer toggle | open | close | start 5m "tea"
    IpcHandler {
        function toggle(): void {
            if (WindowManager.timerVisible)
                WindowManager.timerVisible = false;
            else
                root.openWindow();
        }

        function open(): void {
            root.openWindow();
        }

        function close(): void {
            WindowManager.timerVisible = false;
        }

        function start(duration: string, label: string): void {
            Timers.add(Timers.parseDuration(duration), label);
        }

        target: "timer"
    }

    Shortcut {
        sequence: "Escape"
        onActivated: WindowManager.timerVisible = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 8

            StyledText {
                text: "Timer"
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
            }

            Segmented {
                model: [
                    {
                        "label": "Timer",
                        "value": "timer"
                    },
                    {
                        "label": "Stopwatch",
                        "value": "stopwatch"
                    }
                ]
                value: root.mode
                onSelected: v => root.mode = v
            }

            IconButton {
                icon: "close"
                size: 36
                onClicked: WindowManager.timerVisible = false
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mode === "timer"
            spacing: 18

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.leftMargin: 4
                    text: "Quick start"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: root.presets

                        Rectangle {
                            id: tile

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 62
                            radius: 18
                            color: tileArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor
                            scale: tileArea.pressed ? 0.96 : 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 0

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tile.modelData.n
                                    font.pixelSize: 22
                                    font.weight: Font.DemiBold
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tile.modelData.unit
                                    color: Appearance.mutedColor
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: tileArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Timers.add(tile.modelData.seconds, "")
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animFast
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.leftMargin: 4
                    text: "Custom"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 8

                    FieldInput {
                        id: timeField

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        icon: "timer"
                        placeholder: "5:30, 90, 1h 30m"
                        onAccepted: root.startTyped()
                    }

                    FieldInput {
                        id: nameField

                        Layout.preferredWidth: 120
                        placeholder: "Name"
                        onAccepted: root.startTyped()
                    }

                    IconButton {
                        icon: "play_arrow"
                        size: 44
                        iconSize: 26
                        toggled: true
                        onClicked: root.startTyped()
                    }
                }

                StyledText {
                    id: hint

                    Layout.leftMargin: 4
                    visible: text !== ""
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                }
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.leftMargin: 4
                    text: "Timers"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Item {
                    Layout.fillWidth: true
                }

                PillButton {
                    visible: root.hasDone
                    implicitHeight: 28
                    text: "Clear finished"
                    onClicked: Timers.clearDone()
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: -8
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: Timers.timers

                delegate: Rectangle {
                    id: card

                    required property var modelData
                    readonly property real remaining: {
                        Timers.now;
                        return Timers.left(modelData);
                    }
                    readonly property bool done: modelData.state === "done"
                    readonly property bool paused: modelData.state === "paused"
                    readonly property color ink: done ? Appearance.accentContrastColor : Appearance.fgColor

                    width: list.width
                    height: 84
                    radius: 24
                    color: done ? Appearance.accentColor : Appearance.surfaceColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 14

                        Item {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56

                            TimeRing {
                                anchors.fill: parent
                                value: card.done ? 1 : card.remaining / card.modelData.seconds
                                trackColor: card.done ? Qt.alpha(Appearance.accentContrastColor, 0.25) : Appearance.surfaceHighColor
                                fillColor: card.done ? Appearance.accentContrastColor : Appearance.accentColor
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: card.done ? "check" : (card.paused ? "pause" : "timer")
                                font.pixelSize: 22
                                color: card.done ? Appearance.accentContrastColor : (card.paused ? Appearance.mutedColor : Appearance.accentColor)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: card.done ? "Done" : Timers.format(Math.ceil(card.remaining))
                                color: card.ink
                                elide: Text.ElideRight
                                font.pixelSize: 26
                                font.weight: Font.DemiBold
                                font.features: {
                                    "tnum": 1
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: (card.modelData.label !== "" ? card.modelData.label + "  ·  " : "") + Timers.format(card.modelData.seconds) + (card.paused ? "  ·  paused" : "")
                                color: card.ink
                                opacity: 0.65
                                elide: Text.ElideRight
                                font.pixelSize: 12
                            }
                        }

                        Row {
                            spacing: 0

                            IconButton {
                                visible: !card.done
                                icon: card.modelData.state === "running" ? "pause" : "play_arrow"
                                size: 38
                                iconSize: 22
                                onClicked: card.modelData.state === "running" ? Timers.pause(card.modelData.id) : Timers.resume(card.modelData.id)
                            }

                            IconButton {
                                icon: "restart_alt"
                                size: 38
                                iconSize: 22
                                color: card.ink
                                onClicked: Timers.restart(card.modelData.id)
                            }

                            IconButton {
                                icon: "close"
                                size: 38
                                iconSize: 22
                                color: card.ink
                                onClicked: Timers.remove(card.modelData.id)
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: Timers.timers.length === 0
                    spacing: 8

                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: "timer"
                        font.pixelSize: 40
                        color: Appearance.mutedColor
                        opacity: 0.6
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No timers yet"
                        color: Appearance.mutedColor
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mode === "stopwatch"
            spacing: 22

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 150

                StyledText {
                    anchors.centerIn: parent
                    text: {
                        Timers.now;
                        return Timers.format(Timers.swElapsed(), true);
                    }
                    font.pixelSize: 60
                    font.weight: Font.DemiBold
                    font.features: {
                        "tnum": 1
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 22

                IconButton {
                    icon: "restart_alt"
                    size: 52
                    iconSize: 26
                    enabled: Timers.stopwatch.elapsed > 0 || Timers.stopwatch.running
                    opacity: enabled ? 1 : 0.35
                    onClicked: Timers.swReset()
                }

                // start or pause: the one big button
                Rectangle {
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 76
                    radius: 38
                    color: swArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor
                    scale: swArea.pressed ? 0.95 : 1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: Timers.stopwatch.running ? "pause" : "play_arrow"
                        fill: 1
                        font.pixelSize: 38
                        color: Appearance.accentContrastColor
                    }

                    MouseArea {
                        id: swArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Timers.swToggle()
                    }
                }

                IconButton {
                    icon: "flag"
                    size: 52
                    iconSize: 26
                    enabled: Timers.stopwatch.running
                    opacity: enabled ? 1 : 0.35
                    onClicked: Timers.swLap()
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: Timers.stopwatch.laps

                delegate: Rectangle {
                    id: lap

                    required property real modelData
                    required property int index

                    width: ListView.view.width
                    height: 46
                    radius: 16
                    color: Appearance.surfaceColor

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Lap " + (Timers.stopwatch.laps.length - lap.index)
                        color: Appearance.mutedColor
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: Timers.format(lap.modelData, true)
                        font.weight: Font.Medium
                        font.features: {
                            "tnum": 1
                        }
                    }
                }
            }
        }
    }
}
