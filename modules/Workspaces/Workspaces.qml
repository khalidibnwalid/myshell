pragma ComponentBehavior: Bound

import "../../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

Scope {
    GlobalShortcut {
        name: "workspaces"
        onPressed: lazyloader.active = !lazyloader.active
    }

    Connections {
        target: Hyprland

        function onRawEvent() {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    LazyLoader {
        id: lazyloader
        active: false

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: root

                property real scale: 0.1
                implicitWidth: contentGrid.implicitWidth + 16
                implicitHeight: contentGrid.implicitHeight + 16
                WlrLayershell.layer: WlrLayer.Overlay
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.bgColor
                    opacity: 0.5
                    radius: 16
                    border.color: Appearance.accentColor
                    border.width: 2
                }

                GridLayout {
                    id: contentGrid
                    rows: 2
                    columns: 5
                    rowSpacing: 8
                    columnSpacing: 8
                    anchors.centerIn: parent

                    // workspaces
                    Repeater {
                        model: Hyprland.workspaces.values[Hyprland.workspaces.values.length - 1]?.id ?? 10

                        delegate: Rectangle {
                            id: workspaceContainer

                            required property int index
                            property HyprlandWorkspace workspace: Hyprland.workspaces.values.find(w => w.id === index + 1) ?? null
                            property HyprlandMonitor monitor: Hyprland.monitors.values[0] // for now

                            implicitWidth: monitor.width * root.scale
                            implicitHeight: monitor.height * root.scale

                            color: "transparent"
                            radius: 8

                            Rectangle {
                                anchors.fill: parent
                                color: Appearance.accentColor
                                opacity: workspace?.focused ? 0.3 : 0
                                radius: 8
                                border.color: workspace?.focused ? Appearance.accentColor : "transparent"
                                border.width: 2
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch(`workspace ${workspaceContainer.index + 1}`)
                            }

                            // toplevels
                            Repeater {
                                model: workspaceContainer.workspace?.toplevels

                                delegate: ScreencopyView {
                                    id: toplevel

                                    required property HyprlandToplevel modelData
                                    property Toplevel waylandHandle: modelData?.wayland
                                    property var toplevelData: modelData.lastIpcObject

                                    captureSource: waylandHandle
                                    live: true

                                    // I spent 2 days trying to figure out why the screen was viewed smaller than it actually is,
                                    // turns monitor.width doesn't account for scale
                                    width: (toplevelData.size[0] / monitor.width) * workspaceContainer.implicitWidth * monitor.scale
                                    height: (toplevelData.size[1] / monitor.height) * workspaceContainer.implicitHeight * monitor.scale

                                    x: (toplevelData.at[0]) * root.scale * monitor.scale
                                    y: (toplevelData.at[1]) * root.scale * monitor.scale
                                    z: (waylandHandle.fullscreen || waylandHandle.maximized) ? 2 : toplevelData.floating

                                    IconImage {
                                        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(toplevel.toplevelData?.class)?.icon, "image-missing")
                                        implicitSize: 48
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        anchors.fill: parent

                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton)
                                                toplevel.waylandHandle.activate();
                                            else if (mouse.button === Qt.RightButton)
                                                toplevel.waylandHandle.close();
                                        }
                                    }
                                }
                            }

                            Text {
                                text: workspaceContainer.index + 1
                                color: Appearance.fgColor
                                font.pixelSize: 28
                                font.weight: Font.DemiBold
                                x: 14
                                z: 4
                                opacity: 0.7
                                anchors.bottom: parent.bottom
                            }
                        }
                    }
                }
            }
        }
    }
}
