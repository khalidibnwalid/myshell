import "../../config/"
import "./BarBottomItems.qml"
import "./BarFrame.qml"
import "./BarWS.qml"
import QtQuick
import Quickshell

Scope {
    id: root

    readonly property int railWidth: 48
    readonly property bool barOnRight: Config.layout.barPosition === "right"
    readonly property int contentLeftPadding: barOnRight ? 2 : 8
    readonly property int contentRightPadding: barOnRight ? 8 : 2

    BarFrame {
    }

    Variants {
        model: Quickshell.screens

        // Real bar window. This is intentionally a normal edge panel so
        // applications and other shell modules account for its width.
        PanelWindow {
            id: barWindow

            required property var modelData

            screen: modelData
            visible: true
            implicitWidth: root.railWidth
            color: "transparent"
            exclusiveZone: root.railWidth

            anchors {
                top: true
                bottom: true
                right: root.barOnRight
                left: !root.barOnRight
            }

            Rectangle {
                id: rail

                anchors.fill: parent
                color: Qt.alpha("#000000", 0.5)
                radius: 0

                BarWS {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 20
                        leftMargin: root.contentLeftPadding
                        rightMargin: root.contentRightPadding
                    }
                }

                BarBottomItems {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        bottomMargin: 18
                        leftMargin: root.contentLeftPadding
                        rightMargin: root.contentRightPadding
                    }
                }
            }
        }
    }
}
