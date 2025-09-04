import "../.."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string time

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: true
            implicitWidth: 60

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
                    // anchors.margins: 16
                    // spacing: 24
                    anchors {
                        fill: parent
                        top: parent.top
                        left: parent.left
                        bottom: parent.bottom
                    }

                    BarButton {
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
