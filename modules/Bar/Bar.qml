import "../../config/"
import "../../components/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell

Scope {
    id: root

    Binding {
        target: WindowManager
        property: "barWindows"
        value: bars.instances
    }

    Variants {
        id: bars

        model: Quickshell.screens

        PanelWindow {
            id: panelWindow

            required property var modelData

            readonly property bool horizontal: Config.barHorizontal

            screen: modelData
            visible: true
            implicitWidth: Config.barSize
            implicitHeight: Config.barSize
            color: "transparent"

            // a side bar spans the screen's height, a top or bottom bar its width
            anchors {
                top: Config.barPosition !== "bottom"
                bottom: Config.barPosition !== "top"
                left: Config.barPosition !== "right"
                right: Config.barPosition !== "left"
            }

            // translucent bar background (blurred by the compositor)
            Rectangle {
                anchors.fill: parent
                color: Appearance.panelColor
            }

            // start: search + workspaces
            GridLayout {
                x: panelWindow.horizontal ? 8 : Math.round((parent.width - width) / 2)
                y: panelWindow.horizontal ? Math.round((parent.height - height) / 2) : 8
                columns: panelWindow.horizontal ? -1 : 1
                rowSpacing: 14
                columnSpacing: 14

                // search / launcher button
                Rectangle {
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    color: WindowManager.searchVisible ? Appearance.accentColor : (searchArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
                    scale: searchArea.pressed ? 0.92 : 1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: "apps"
                        font.pixelSize: 20
                        color: WindowManager.searchVisible ? Appearance.onAccentColor : Appearance.fgColor
                    }

                    MouseArea {
                        id: searchArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WindowManager.toggleSearchVisible()
                    }

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
                }

                BarWS {
                    Layout.alignment: Qt.AlignCenter
                    barWindow: panelWindow
                }
            }

            // middle: clock
            BarClock {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: panelWindow.horizontal ? 0 : 20
            }

            // end: tray + status icons
            GridLayout {
                x: panelWindow.horizontal ? parent.width - width - 16 : Math.round((parent.width - width) / 2)
                y: panelWindow.horizontal ? Math.round((parent.height - height) / 2) : parent.height - height - 16
                columns: panelWindow.horizontal ? -1 : 1
                rowSpacing: 10
                columnSpacing: 10

                BarTrays {
                    Layout.alignment: Qt.AlignCenter
                    barWindow: panelWindow
                }

                BarBottomItems {
                    Layout.alignment: Qt.AlignCenter
                    barWindow: panelWindow
                }
            }
        }
    }
}
