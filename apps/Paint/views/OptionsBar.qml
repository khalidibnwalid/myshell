import ".."
import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The options of the chosen tool (like Paint.NET's tool bar).
Flow {
    id: root

    readonly property string tool: PaintDoc.tool
    readonly property bool brushLike: ["brush", "eraser", "clone", "recolor"].indexOf(tool) >= 0
    readonly property bool selecting: ["rectSelect", "ellipseSelect", "lasso", "wand"].indexOf(tool) >= 0
    readonly property var fonts: Qt.fontFamilies()

    signal textOptionChanged
    signal commitRequested

    spacing: 10

    StyledText {
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: ({
                "rectSelect": "Rectangle select",
                "ellipseSelect": "Ellipse select",
                "lasso": "Lasso select",
                "wand": "Magic wand",
                "moveSelected": "Move selected pixels",
                "moveSel": "Move selection",
                "zoom": "Zoom",
                "pan": "Pan",
                "bucket": "Paint bucket",
                "gradient": "Gradient",
                "brush": "Paintbrush",
                "eraser": "Eraser",
                "pencil": "Pencil",
                "picker": "Color picker",
                "clone": "Clone stamp",
                "recolor": "Recolor",
                "text": "Text",
                "line": "Line / curve",
                "shape": "Shapes"
            })[root.tool] + ":"
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    NumberStepper {
        visible: root.brushLike || root.tool === "pencil"
        label: "Size"
        value: PaintDoc.brushSize
        from: 1
        to: 500
        step: root.tool === "pencil" ? 1 : (PaintDoc.brushSize >= 50 ? 5 : 1)
        onChanged: v => PaintDoc.brushSize = v
    }

    NumberStepper {
        visible: root.brushLike
        label: "Hardness"
        value: PaintDoc.hardness * 100
        suffix: "%"
        from: 0
        to: 100
        step: 5
        onChanged: v => PaintDoc.hardness = v / 100
    }

    NumberStepper {
        visible: root.brushLike
        label: "Spacing"
        value: PaintDoc.spacing * 100
        suffix: "%"
        from: 1
        to: 100
        step: 5
        onChanged: v => PaintDoc.spacing = v / 100
    }

    NumberStepper {
        visible: root.tool === "bucket" || root.tool === "wand" || root.tool === "recolor"
        label: "Tolerance"
        value: PaintDoc.tolerance * 100
        suffix: "%"
        from: 0
        to: 100
        step: 5
        onChanged: v => PaintDoc.tolerance = v / 100
    }

    Segmented {
        visible: root.tool === "bucket" || root.tool === "wand"
        model: [
            {
                "label": "Contiguous",
                "value": false
            },
            {
                "label": "Global",
                "value": true
            }
        ]
        value: PaintDoc.globalFill
        onSelected: v => PaintDoc.globalFill = v
    }

    Segmented {
        visible: root.selecting
        model: [
            {
                "label": "Replace",
                "value": "replace"
            },
            {
                "label": "Add",
                "value": "add"
            },
            {
                "label": "Subtract",
                "value": "subtract"
            },
            {
                "label": "Intersect",
                "value": "intersect"
            }
        ]
        value: PaintDoc.selMode
        onSelected: v => PaintDoc.selMode = v
    }

    Dropdown {
        visible: root.tool === "gradient"
        model: [
            {
                "label": "Linear",
                "value": "linear"
            },
            {
                "label": "Reflected",
                "value": "reflected"
            },
            {
                "label": "Diamond",
                "value": "diamond"
            },
            {
                "label": "Radial",
                "value": "radial"
            },
            {
                "label": "Conical",
                "value": "conical"
            }
        ]
        value: PaintDoc.gradientMode
        popupWidth: 180
        onSelected: v => PaintDoc.gradientMode = v
    }

    Dropdown {
        visible: root.tool === "shape"
        model: [
            {
                "label": "Rectangle",
                "value": "rect"
            },
            {
                "label": "Rounded rectangle",
                "value": "rrect"
            },
            {
                "label": "Ellipse",
                "value": "ellipse"
            },
            {
                "label": "Triangle",
                "value": "triangle"
            },
            {
                "label": "Diamond",
                "value": "diamond"
            },
            {
                "label": "Pentagon",
                "value": "pentagon"
            },
            {
                "label": "Hexagon",
                "value": "hexagon"
            },
            {
                "label": "Star",
                "value": "star"
            }
        ]
        value: PaintDoc.shapeKind
        popupWidth: 220
        onSelected: v => PaintDoc.shapeKind = v
    }

    Segmented {
        visible: root.tool === "shape"
        model: [
            {
                "label": "Outline",
                "value": "outline"
            },
            {
                "label": "Filled",
                "value": "fill"
            },
            {
                "label": "Both",
                "value": "both"
            }
        ]
        value: PaintDoc.shapeFill
        onSelected: v => PaintDoc.shapeFill = v
    }

    NumberStepper {
        visible: root.tool === "line" || root.tool === "shape"
        label: "Width"
        value: PaintDoc.lineWidth
        from: 1
        to: 200
        onChanged: v => PaintDoc.lineWidth = v
    }

    NumberStepper {
        visible: root.tool === "shape" && PaintDoc.shapeKind === "rrect"
        label: "Radius"
        value: PaintDoc.cornerRadius
        from: 0
        to: 500
        step: 2
        onChanged: v => PaintDoc.cornerRadius = v
    }

    PillButton {
        visible: root.brushLike || root.tool === "line" || root.tool === "shape"
        height: 32
        text: "Antialiasing"
        icon: PaintDoc.antialias ? "check_box" : "check_box_outline_blank"
        toggled: PaintDoc.antialias
        onClicked: PaintDoc.antialias = !PaintDoc.antialias
    }

    PillButton {
        visible: root.tool === "line" || root.tool === "shape"
        height: 32
        text: "Finish  (Enter)"
        icon: "check"
        onClicked: root.commitRequested()
    }

    Segmented {
        visible: root.tool === "picker"
        model: [
            {
                "label": "Layer",
                "value": "layer"
            },
            {
                "label": "Image",
                "value": "image"
            }
        ]
        value: PaintDoc.pickSource
        onSelected: v => PaintDoc.pickSource = v
    }

    Dropdown {
        visible: root.tool === "text"
        model: root.fonts
        value: PaintDoc.textFamily
        searchable: true
        popupWidth: 260
        onSelected: v => {
            PaintDoc.textFamily = v;
            root.textOptionChanged();
        }
    }

    NumberStepper {
        visible: root.tool === "text"
        label: "Size"
        value: PaintDoc.textSize
        from: 4
        to: 600
        step: 2
        onChanged: v => {
            PaintDoc.textSize = v;
            root.textOptionChanged();
        }
    }

    Row {
        visible: root.tool === "text"
        spacing: 2

        IconButton {
            icon: "format_bold"
            size: 32
            toggled: PaintDoc.textBold
            onClicked: {
                PaintDoc.textBold = !PaintDoc.textBold;
                root.textOptionChanged();
            }
        }

        IconButton {
            icon: "format_italic"
            size: 32
            toggled: PaintDoc.textItalic
            onClicked: {
                PaintDoc.textItalic = !PaintDoc.textItalic;
                root.textOptionChanged();
            }
        }

        IconButton {
            icon: "format_underlined"
            size: 32
            toggled: PaintDoc.textUnderline
            onClicked: {
                PaintDoc.textUnderline = !PaintDoc.textUnderline;
                root.textOptionChanged();
            }
        }
    }

    Segmented {
        visible: root.tool === "text"
        model: [
            {
                "label": "Left",
                "value": "left"
            },
            {
                "label": "Center",
                "value": "center"
            },
            {
                "label": "Right",
                "value": "right"
            }
        ]
        value: PaintDoc.textAlign
        onSelected: v => {
            PaintDoc.textAlign = v;
            root.textOptionChanged();
        }
    }

    StyledText {
        visible: root.tool === "text"
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: "Click to type. Ctrl+Enter or a click elsewhere finishes; Esc cancels"
        font.pixelSize: 12
        color: Appearance.mutedColor
    }

    StyledText {
        visible: root.tool === "zoom"
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: "Click zooms in, right click or Alt+click zooms out. Ctrl+wheel zooms anywhere"
        font.pixelSize: 12
        color: Appearance.mutedColor
    }

    StyledText {
        visible: root.tool === "clone"
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: "Ctrl+click picks the source"
        font.pixelSize: 12
        color: Appearance.mutedColor
    }

    StyledText {
        visible: root.tool === "recolor"
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: "Paints the primary colour over the secondary colour"
        font.pixelSize: 12
        color: Appearance.mutedColor
    }
}
