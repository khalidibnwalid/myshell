import "../../config/"
import "../../components"
import "../../services" as Services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Shortcuts for the screen utilities, and the frame shown around the area being recorded.
// bind = , Print, global, quickshell:screenshot
// bind = $mainMod SHIFT, T, global, quickshell:ocr   (starts with "Extract text" chosen)
// bind = $mainMod SHIFT, C, global, quickshell:colorpicker
// bind = $mainMod SHIFT, R, global, quickshell:record
Scope {
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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
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

                RowLayout {
                    id: barRow

                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: [
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
                                "icon": "videocam",
                                "value": "video"
                            }
                        ]

                        // the chosen action is filled with the primary (accent) colour
                        Rectangle {
                            id: choice

                            required property var modelData
                            readonly property bool current: Services.ScreenTools.captureMode === modelData.value

                            implicitWidth: 42
                            implicitHeight: 42
                            radius: width / 2
                            color: current ? Appearance.accentColor : (choiceArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

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
                                onClicked: Services.ScreenTools.setMode(choice.modelData.value)
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
            if (Services.ScreenTools.selecting)
                barDelay.restart();
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
