import "../../config/"
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// One mark of the screenshot editor, drawn over the image in the image's own pixels:
// pen, marker, arrow, rect, text, pixelate, blur (a crop draws nothing).
// pixelate and blur take their pixels from `source` (the image), so they hide what is under them.
Item {
    id: root

    property var mark: null
    property Item source: null
    readonly property string kind: mark ? mark.kind : ""
    // a rectangle mark with its corners in any order
    readonly property rect box: mark && mark.x2 !== undefined ? Qt.rect(Math.min(mark.x1, mark.x2), Math.min(mark.y1, mark.y2), Math.abs(mark.x2 - mark.x1), Math.abs(mark.y2 - mark.y1)) : Qt.rect(0, 0, 0, 0)

    anchors.fill: parent

    Loader {
        anchors.fill: parent
        active: root.mark !== null
        sourceComponent: {
            switch (root.kind) {
            case "pen":
            case "marker":
                return strokeComp;
            case "arrow":
                return arrowComp;
            case "rect":
                return rectComp;
            case "text":
                return textComp;
            case "pixelate":
                return pixelComp;
            case "blur":
                return blurComp;
            }
            return null;
        }
    }

    // pen and marker: a line through the points. The marker is drawn opaque and faded as a whole,
    // so where it crosses itself it does not get darker; its layer covers only the stroke's box
    Component {
        id: strokeComp

        // in an Item: the Loader sizes its item to the whole sheet, the stroke keeps its own box
        Item {
            Shape {
                id: stroke

                readonly property var pts: root.mark.points
                readonly property real w: root.mark.width
                readonly property real minX: Math.min.apply(null, pts.map(p => p.x)) - w
                readonly property real minY: Math.min.apply(null, pts.map(p => p.y)) - w

                x: minX
                y: minY
                width: Math.max.apply(null, pts.map(p => p.x)) + w - minX
                height: Math.max.apply(null, pts.map(p => p.y)) + w - minY
                preferredRendererType: Shape.CurveRenderer
                opacity: root.kind === "marker" ? 0.42 : 1
                layer.enabled: root.kind === "marker"

                ShapePath {
                    strokeColor: root.mark.color
                    strokeWidth: stroke.w
                    fillColor: "transparent"
                    capStyle: root.kind === "marker" ? ShapePath.SquareCap : ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        // a single click leaves a dot
                        path: {
                            const out = stroke.pts.map(p => Qt.point(p.x - stroke.minX, p.y - stroke.minY));
                            if (out.length === 1)
                                out.push(Qt.point(out[0].x + 0.01, out[0].y));
                            return out;
                        }
                    }
                }
            }
        }
    }

    // a line with a filled head; the line stops inside the head so its round end does not show at the tip
    Component {
        id: arrowComp

        Shape {
            id: arrow

            readonly property real w: root.mark.width
            readonly property real dx: root.mark.x2 - root.mark.x1
            readonly property real dy: root.mark.y2 - root.mark.y1
            readonly property real len: Math.max(0.001, Math.sqrt(dx * dx + dy * dy))
            readonly property real ux: dx / len
            readonly property real uy: dy / len
            readonly property real head: Math.min(len, Math.max(w * 4, 16))
            readonly property real half: head * 0.62
            readonly property point base: Qt.point(root.mark.x2 - ux * head * 0.85, root.mark.y2 - uy * head * 0.85)

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.mark.color
                strokeWidth: arrow.w
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathPolyline {
                    path: [Qt.point(root.mark.x1, root.mark.y1), arrow.base]
                }
            }

            ShapePath {
                strokeColor: root.mark.color
                strokeWidth: Math.max(1, arrow.w * 0.5)
                joinStyle: ShapePath.RoundJoin
                fillColor: root.mark.color

                PathPolyline {
                    path: [Qt.point(root.mark.x2, root.mark.y2), Qt.point(root.mark.x2 - arrow.ux * arrow.head - arrow.uy * arrow.half, root.mark.y2 - arrow.uy * arrow.head + arrow.ux * arrow.half), Qt.point(root.mark.x2 - arrow.ux * arrow.head + arrow.uy * arrow.half, root.mark.y2 - arrow.uy * arrow.head - arrow.ux * arrow.half), Qt.point(root.mark.x2, root.mark.y2)]
                }
            }
        }
    }

    Component {
        id: rectComp

        Item {
            Rectangle {
                x: root.box.x
                y: root.box.y
                width: root.box.width
                height: root.box.height
                radius: root.mark.width
                color: "transparent"
                border.width: root.mark.width
                border.color: root.mark.color
            }
        }
    }

    Component {
        id: textComp

        Item {
            Text {
                x: root.mark.x
                y: root.mark.y
                text: root.mark.text
                color: root.mark.color
                font.family: Appearance.fontFamily
                font.pixelSize: root.mark.size
                font.weight: Font.Bold
                // a thin outline in the opposite shade keeps it readable on any background
                style: Text.Outline
                styleColor: Qt.color(root.mark.color).hslLightness > 0.5 ? "#000000" : "#ffffff"
            }
        }
    }

    // the image under the box, sampled at one pixel per cell and shown without smoothing
    Component {
        id: pixelComp

        Item {
            Item {
                x: root.box.x
                y: root.box.y
                width: Math.max(1, root.box.width)
                height: Math.max(1, root.box.height)
                clip: true

                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: root.source
                    sourceRect: root.box
                    textureSize: Qt.size(Math.max(1, Math.ceil(root.box.width / root.mark.cell)), Math.max(1, Math.ceil(root.box.height / root.mark.cell)))
                    smooth: false
                }
            }
        }
    }

    // the image under the box, blurred; the blur reads a margin around the box so its edges stay solid
    Component {
        id: blurComp

        Item {
            Item {
                readonly property real pad: root.mark.cell * 3

                x: root.box.x
                y: root.box.y
                width: Math.max(1, root.box.width)
                height: Math.max(1, root.box.height)
                clip: true

                ShaderEffectSource {
                    id: under

                    x: -parent.pad
                    y: -parent.pad
                    width: parent.width + 2 * parent.pad
                    height: parent.height + 2 * parent.pad
                    sourceItem: root.source
                    sourceRect: Qt.rect(root.box.x - parent.pad, root.box.y - parent.pad, width, height)
                    visible: false
                }

                MultiEffect {
                    anchors.fill: under
                    source: under
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    blurMultiplier: 1
                }
            }
        }
    }
}
