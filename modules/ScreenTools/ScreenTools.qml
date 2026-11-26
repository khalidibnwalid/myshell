import "../../config/"
import "../../components"
import "../../services" as Services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Shortcuts for the screen utilities, and the frame shown around the area being recorded.
// bind = , Print, global, quickshell:screenshot
// bind = $mainMod SHIFT, T, global, quickshell:ocr   (starts with "Extract text" chosen)
// bind = $mainMod SHIFT, C, global, quickshell:colorpicker
// bind = $mainMod SHIFT, R, global, quickshell:record
Scope {
    id: root

    readonly property var options: [
        {
            "icon": "screenshot_region",
            "value": "screenshot"
        },
        {
            "icon": "document_scanner",
            "value": "text"
        },
        {
            "icon": "qr_code_scanner",
            "value": "qr"
        },
        {
            "icon": "colorize",
            "value": "color"
        },
        {
            "icon": "videocam",
            "value": "video"
        }
    ]

    // the option the keyboard is on (Left/Right/Tab move it, Enter or Space chooses it)
    property int focusIndex: 0

    function activate(value) {
        if (value === "color")
            Services.ScreenTools.pickColorFromSelector();
        else
            Services.ScreenTools.setMode(value);
    }

    GlobalShortcut {
        name: "screenshot"
        onPressed: Services.ScreenTools.screenshot()
    }

    GlobalShortcut {
        name: "ocr"
        onPressed: Services.ScreenTools.extractText()
    }

    GlobalShortcut {
        name: "colorpicker"
        onPressed: Services.ScreenTools.pickColor()
    }

    GlobalShortcut {
        name: "record"
        onPressed: Services.ScreenTools.toggleRecording()
    }

    // qs ipc call capture edit /path/to/image.png | closeEditor | screenshot
    IpcHandler {
        function edit(path: string): void {
            Services.ScreenTools.editImage(path);
        }

        function closeEditor(): void {
            Services.ScreenTools.closeEditor();
        }

        function screenshot(): void {
            Services.ScreenTools.screenshot();
        }

        target: "capture"
    }

    // the screenshot editor exists only while it has an image
    LazyLoader {
        active: Services.ScreenTools.editorPath !== ""

        ShotEditor {
        }
    }

    // Options shown above the area selection: take a screenshot, or extract the text in it.
    // slurp draws the selection; this bar is mapped after it so it lies on top and takes clicks.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: Services.ScreenTools.selecting && barDelay.shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            margins.top: 24
            implicitWidth: optionBar.implicitWidth
            implicitHeight: optionBar.implicitHeight

            Rectangle {
                id: optionBar

                implicitWidth: barRow.implicitWidth + 20
                implicitHeight: 56
                radius: height / 2
                color: Appearance.panelColor
                border.width: 1
                border.color: Appearance.hairlineColor
                focus: true

                // this window holds the keyboard while it is up, so Esc cancels the selection here
                Keys.onPressed: event => {
                    const n = root.options.length;
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)))
                        root.focusIndex = (root.focusIndex + 1) % n;
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_Tab)
                        root.focusIndex = (root.focusIndex + n - 1) % n;
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                        root.activate(root.options[root.focusIndex].value);
                    else if (event.key === Qt.Key_Escape)
                        Quickshell.execDetached(["pkill", "-x", "slurp"]);
                    else
                        return;
                    event.accepted = true;
                }

                RowLayout {
                    id: barRow

                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: root.options

                        // the chosen action is filled with the primary (accent) colour
                        Rectangle {
                            id: choice

                            required property var modelData
                            required property int index
                            readonly property bool current: modelData.value !== "color" && Services.ScreenTools.captureMode === modelData.value

                            implicitWidth: 42
                            implicitHeight: 42
                            radius: width / 2
                            readonly property bool focused: root.focusIndex === index
                            color: current ? Appearance.accentColor : (choiceArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

                            border.width: focused ? 2 : 0
                            border.color: Appearance.fgColor

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: choice.modelData.icon
                                font.pixelSize: 24
                                color: choice.current ? Appearance.accentContrastColor : Appearance.fgColor
                            }

                            MouseArea {
                                id: choiceArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activate(choice.modelData.value)
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
        }
    }

    Timer {
        id: barDelay

        // slurp must be on screen first, so the bar is mapped above it
        property bool shown: false

        interval: 450
        onTriggered: shown = true
    }

    Connections {
        function onSelectingChanged() {
            if (Services.ScreenTools.selecting) {
                root.focusIndex = 0;
                for (let i = 0; i < root.options.length; i++) {
                    if (root.options[i].value === Services.ScreenTools.captureMode)
                        root.focusIndex = i;
                }
                barDelay.restart();
            }
            else
                barDelay.shown = false;
        }

        target: Services.ScreenTools
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            readonly property rect region: Services.ScreenTools.region
            // the recorded area in this screen's coordinates
            readonly property real rx: region.x - modelData.x
            readonly property real ry: region.y - modelData.y
            readonly property bool onThisScreen: rx < modelData.width && ry < modelData.height && rx + region.width > 0 && ry + region.height > 0
            // the frame and the pill sit just outside the area, so they are not in the video
            readonly property int frameWidth: 2
            readonly property int frameGap: 1
            readonly property int pillGap: 10
            readonly property bool roomBelow: ry + region.height + pillGap + pill.height + 4 <= modelData.height
            readonly property bool roomAbove: ry - pillGap - pill.height - 4 >= 0

            screen: modelData
            visible: Services.ScreenTools.recording && onThisScreen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // only the pill takes input, the rest is click-through
            mask: Region {
                item: pill.visible ? pill : null
            }

            Rectangle {
                x: window.rx - window.frameWidth - window.frameGap
                y: window.ry - window.frameWidth - window.frameGap
                width: window.region.width + 2 * (window.frameWidth + window.frameGap)
                height: window.region.height + 2 * (window.frameWidth + window.frameGap)
                radius: 4
                color: "transparent"
                border.width: window.frameWidth
                border.color: "#ff5f5f"
            }

            // timer + stop, below the area (above it when there is no room)
            Rectangle {
                id: pill

                visible: window.roomBelow || window.roomAbove
                x: Math.max(8, Math.min(window.modelData.width - width - 8, window.rx + (window.region.width - width) / 2))
                y: window.roomBelow ? window.ry + window.region.height + window.pillGap : window.ry - window.pillGap - height
                width: pillRow.implicitWidth + 20
                height: 40
                radius: 20
                color: Appearance.panelColor
                border.width: 1
                border.color: Appearance.hairlineColor

                RowLayout {
                    id: pillRow

                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        Layout.leftMargin: 6
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: "#ff5f5f"

                        SequentialAnimation on opacity {
                            running: window.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.25
                                duration: 700
                            }

                            NumberAnimation {
                                to: 1
                                duration: 700
                            }
                        }
                    }

                    StyledText {
                        text: Services.ScreenTools.elapsedText
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.features: {
                            "tnum": 1
                        }
                    }

                    IconButton {
                        icon: "stop_circle"
                        size: 30
                        iconSize: 20
                        color: "#ff5f5f"
                        onClicked: Services.ScreenTools.stopRecording()
                    }
                }
            }
        }
    }
}
