import QtQuick
import QtQuick.Shapes
import Quickshell

Scope {
    id: root

    readonly property int frameWidth: 8

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: frameWindow

            required property var modelData

            screen: modelData
            visible: true
            color: "transparent"
            focusable: false
            aboveWindows: true
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // The outer edge is square and flush with the monitor. The inner
            // cutout is rounded, producing the inverted-corner shape from the
            // reference without leaving gaps in the screen corners.
            Shape {
                anchors.fill: parent

                ShapePath {
                    fillColor: Qt.alpha("#000000", 0.5)
                    fillRule: ShapePath.OddEvenFill
                    strokeColor: "transparent"
                    strokeWidth: -1

                    PathRectangle {
                        width: frameWindow.width
                        height: frameWindow.height
                        radius: 0
                    }

                    PathRectangle {
                        x: root.frameWidth
                        y: root.frameWidth
                        width: frameWindow.width - (root.frameWidth * 2)
                        height: frameWindow.height - (root.frameWidth * 2)
                        radius: 30
                    }
                }
            }

            // Keep only the thin frame edges in the input region. The middle
            // of the monitor remains fully interactive for applications.
            mask: Region {
                Region {
                    x: 0
                    y: 0
                    width: frameWindow.width
                    height: root.frameWidth
                }
                Region {
                    x: 0
                    y: frameWindow.height - root.frameWidth
                    width: frameWindow.width
                    height: root.frameWidth
                }
                Region {
                    x: 0
                    y: 0
                    width: root.frameWidth
                    height: frameWindow.height
                }
                Region {
                    x: frameWindow.width - root.frameWidth
                    y: 0
                    width: root.frameWidth
                    height: frameWindow.height
                }
            }
        }
    }
}
