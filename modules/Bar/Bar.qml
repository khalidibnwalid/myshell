import "../.."
import "../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string time
    property HyprlandWorkspace activeWs: Hyprland.workspaces.values.find(ws => ws.focused)
    property list<HyprlandToplevel> workspaceToplevels: activeWs?.toplevels?.values || []
    // TODO: add floating windows
    property bool shouldShowBarBg: workspaceToplevels.length > 0

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow

            required property var modelData

            screen: modelData
            visible: true
            implicitWidth: 50
            color: "transparent"

            anchors {
                top: true
                right: true
                bottom: true
            }

            // background
            Rectangle {
                width: parent.width
                color: Appearance.bgColor
                height: root.shouldShowBarBg ? parent.height : 0
                y: root.shouldShowBarBg ? 0 : parent.height / 2
                opacity: root.shouldShowBarBg ? 0.6 : 0
                radius: root.shouldShowBarBg ? 0 : 25

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on radius {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: root.shouldShowBarBg ? 250 : 0
                        }

                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutQuart
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: parent ? parent.height : 400
                color: 'transparent'

                BarWS {
                    Layout.alignment: Qt.AlignHCenter
                    anchors.centerIn: parent
                }

                // Bottom Items
                ColumnLayout {
                    implicitHeight: 30

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    // background
                    Rectangle {
                        anchors.margins: 3
                        anchors.fill: parent
                        color: Appearance.bgColor
                        radius: 16
                        border.color: Appearance.borderColor
                        border.width: 2

                        MouseArea {
                            anchors.fill: parent
                            onClicked: WindowManager.setQuickSettingsVisible(!WindowManager.quickSettingsVisible)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    BarClock {
                        timeParts: root.time ? root.time.split("|") : ["", "", ""]
                    }
                }
            }
        }
    }

    Process {
        id: dateProc

        command: ["date", "+%I|%M|%p"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.time = this.text
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: dateProc.running = true
    }
}
