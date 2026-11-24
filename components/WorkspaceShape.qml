import "../config/"
import "WorkspaceShapes.js" as Shapes
import QtQuick
import QtQuick.Shapes

// One workspace marker: a filled or hollow shape from WorkspaceShapes.js.
Item {
    id: root

    property string shape: "dot"
    property real size: 10
    property bool filled: true
    property color fillColor: Appearance.fgColor
    property color lineColor: Appearance.mutedColor

    implicitWidth: size
    implicitHeight: size

    // the plain dot stays a rectangle: cheapest, and the look it always had
    Rectangle {
        anchors.fill: parent
        visible: root.shape === "dot" || root.shape === ""
        radius: width / 2
        color: root.filled ? root.fillColor : "transparent"
        border.width: root.filled ? 0 : 1.5
        border.color: root.lineColor
    }

    Loader {
        anchors.fill: parent
        active: root.shape !== "dot" && root.shape !== ""

        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.filled ? root.fillColor : "transparent"
                strokeColor: root.filled ? "transparent" : root.lineColor
                strokeWidth: root.filled ? 0 : 1.5
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    // inset by half the stroke so the outline stays inside the box
                    path: Shapes.points(root.shape, root.size)
                }
            }
        }
    }
}
