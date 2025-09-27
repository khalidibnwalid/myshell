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
            implicitWidth: 45
            color: "transparent"

            anchors {
                top: true
                right: true
                bottom: true
            }

            Rectangle {
                width: parent.width
                height: parent ? parent.height : 400
                color: 'transparent'

                ColumnLayout {
                    anchors.fill: parent

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter

                        BarWS {
                            
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
