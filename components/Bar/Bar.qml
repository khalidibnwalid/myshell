import "../.."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string time

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow

            required property var modelData

            screen: modelData
            visible: true
            implicitWidth: 60
            Component.onCompleted: {
                console.log(Hyprland.workspaces.values[0].focused);
            }

            anchors {
                top: true
                left: true
                bottom: true
            }

            Rectangle {
                width: parent.width
                height: parent ? parent.height : 400
                color: Appearance.bgColor

                ColumnLayout {
                    anchors.fill: parent

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter

                        Item {
                            id: wsIndicatorBar

                            property int activeIndex: Hyprland.workspaces.values.findIndex((ws) => {
                                return ws.focused;
                            })

                            width: 34
                            height: (26 + 8) * Hyprland.workspaces.values.length // 26px + 8px spacing

                            // Material-style active indicator (vertical)
                            Rectangle {
                                id: activeIndicator

                                width: 36
                                height: 36
                                radius: 14
                                color: Appearance.accentColor
                                x: -1
                                y: wsIndicatorBar.activeIndex * (26 + 8) - 5
                                z: 1
                                opacity: 0.3

                                Behavior on y {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }

                                }

                            }

                            Repeater {
                                model: Hyprland.workspaces.values.length

                                Rectangle {
                                    // Behavior on border.color {
                                    //     ColorAnimation {
                                    //         duration: 200
                                    //         easing.type: Easing.InOutQuad
                                    //     }
                                    // }

                                    required property int index

                                    width: 26
                                    height: Hyprland.workspaces.values[index].focused ? 26 : 26
                                    radius: 10
                                    x: 4
                                    y: index * (26 + 8)
                                    color: Hyprland.workspaces.values[index].focused ? Appearance.accentColor : Appearance.highlightColor
                                    // opacity: Hyprland.workspaces.values[index].focused ? 1.0 : 0.8
                                    // border.color: Hyprland.workspaces.values[index].focused ? Appearance.accentColor : Appearance.highlightColor
                                    // border.width: 4
                                    z: 2

                                    MouseArea {
                                        // You can add logic to switch workspace, etc.

                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Hyprland.workspaces.values[index].activate();
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                            easing.type: Easing.InOutQuad
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

                // Bottom Items
                ColumnLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
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
