import "../../config/"
import "../../components/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell

Scope {
    id: root

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

            // translucent bar background (blurred by the compositor)
            Rectangle {
                anchors.fill: parent
                color: Appearance.panelColor
            }

            // top: search + workspaces
            ColumnLayout {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 8
                }

                spacing: 14

                // search / launcher button
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
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
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // middle: clock
            BarClock {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 20
            }

            // bottom: tray + status icons
            ColumnLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 16
                }

                spacing: 16

                BarTrays {
                    Layout.alignment: Qt.AlignHCenter
                    barWindow: panelWindow
                }

                BarBottomItems {
                    Layout.alignment: Qt.AlignHCenter
                    barWindow: panelWindow
                }
            }
        }
    }
}
