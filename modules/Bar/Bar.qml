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
            // 0 while the bar has a background (45% and up), 1 once it is see-through: the groups of
            // icons then sit on floating "islands" (like the clock) instead of bare wallpaper
            readonly property real islandAmount: Appearance.islandAmount
            readonly property int islandPadding: 7

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
            Rectangle {
                x: startGroup.x - panelWindow.islandPadding
                y: startGroup.y - panelWindow.islandPadding
                width: startGroup.width + panelWindow.islandPadding * 2
                height: startGroup.height + panelWindow.islandPadding * 2
                radius: Math.min(width, height) / 2 > 24 ? 24 : Math.min(width, height) / 2
                color: Qt.alpha(Appearance.bgColor, 0.5 * panelWindow.islandAmount)
                border.width: 1
                border.color: Qt.alpha(Appearance.fgColor, 0.1 * panelWindow.islandAmount)
                visible: panelWindow.islandAmount > 0
            }

            GridLayout {
                id: startGroup

                x: panelWindow.horizontal ? 12 : Math.round((parent.width - width) / 2)
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
                        color: WindowManager.searchVisible ? Appearance.accentContrastColor : Appearance.fgColor
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
            Rectangle {
                x: endGroup.x - panelWindow.islandPadding
                y: endGroup.y - panelWindow.islandPadding
                width: endGroup.width + panelWindow.islandPadding * 2
                height: endGroup.height + panelWindow.islandPadding * 2
                radius: Math.min(width, height) / 2 > 24 ? 24 : Math.min(width, height) / 2
                color: Qt.alpha(Appearance.bgColor, 0.5 * panelWindow.islandAmount)
                border.width: 1
                border.color: Qt.alpha(Appearance.fgColor, 0.1 * panelWindow.islandAmount)
                visible: panelWindow.islandAmount > 0
            }

            GridLayout {
                id: endGroup

                x: panelWindow.horizontal ? parent.width - width - 12 : Math.round((parent.width - width) / 2)
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
