import ".."
import QtQuick
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
            id: root

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

                    anchors.fill: parent
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    BarButton {
                        Text {
                            color: "#fff"
                            // anchors.centerIn: parent
                            text: root.time
                        }

                    }

                }

            }

        }

    }

    Process {
        id: dateProc

        command: ["date"]
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
