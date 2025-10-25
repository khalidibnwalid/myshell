import "../../config/"
import "../../components/"
import "../../services/"
import "./BarTrays.qml"
import "./BarBottomItems.qml"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

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
                right: Config.layout.barPosition === "right"
                left: Config.layout.barPosition === "left"
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

                // bottom islands
                ColumnLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 5
                        bottomMargin: 10
                    }

                    spacing: 10

                    BarTrays {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    BarBottomItems {
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
