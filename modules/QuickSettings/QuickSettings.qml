import "../.."
import "../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    LazyLoader {
        id: lazyloader

        active: WindowManager.quickSettingsVisible

        Variants {
            model: Quickshell.screens

            PanelWindow {
                // focus: false

                id: bottomPanel

                required property var modelData

                screen: modelData
                visible: true
                implicitWidth: 500
                implicitHeight: 500
                color: "transparent"

                anchors {
                    right: true
                    bottom: true
                }

                margins {
                    right: 10
                    bottom: 10
                }

                // background
                Rectangle {
                    anchors.fill: parent
                    color: Appearance.bgColor
                    radius: 24
                    border.color: Appearance.borderColor
                    border.width: 2
                    opacity: 0.5

                    // prevent clicks from going through it
                    MouseArea {
                        anchors.fill: parent
                    }

                }

            }

        }

    }

}
