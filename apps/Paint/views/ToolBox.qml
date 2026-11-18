import ".."
import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The tools, two to a row like Paint.NET's toolbox.
ToolPanel {
    id: root

    readonly property var tools: [
        {
            "id": "rectSelect",
            "icon": "crop_square",
            "name": "Rectangle select",
            "key": "S"
        },
        {
            "id": "moveSelected",
            "icon": "open_with",
            "name": "Move selected pixels",
            "key": "M"
        },
        {
            "id": "lasso",
            "icon": "gesture",
            "name": "Lasso select",
            "key": "A"
        },
        {
            "id": "moveSel",
            "icon": "near_me",
            "name": "Move selection",
            "key": "N"
        },
        {
            "id": "ellipseSelect",
            "icon": "circle",
            "name": "Ellipse select",
            "key": "D"
        },
        {
            "id": "zoom",
            "icon": "zoom_in",
            "name": "Zoom",
            "key": "Z"
        },
        {
            "id": "wand",
            "icon": "auto_fix_high",
            "name": "Magic wand",
            "key": "W"
        },
        {
            "id": "pan",
            "icon": "pan_tool",
            "name": "Pan (or hold Space)",
            "key": "H"
        },
        {
            "id": "bucket",
            "icon": "format_color_fill",
            "name": "Paint bucket",
            "key": "F"
        },
        {
            "id": "gradient",
            "icon": "gradient",
            "name": "Gradient",
            "key": "G"
        },
        {
            "id": "brush",
            "icon": "brush",
            "name": "Paintbrush",
            "key": "B"
        },
        {
            "id": "eraser",
            "icon": "ink_eraser",
            "name": "Eraser",
            "key": "E"
        },
        {
            "id": "pencil",
            "icon": "edit",
            "name": "Pencil",
            "key": "P"
        },
        {
            "id": "picker",
            "icon": "colorize",
            "name": "Color picker",
            "key": "K"
        },
        {
            "id": "clone",
            "icon": "content_copy",
            "name": "Clone stamp",
            "key": "L"
        },
        {
            "id": "recolor",
            "icon": "palette",
            "name": "Recolor",
            "key": "R"
        },
        {
            "id": "text",
            "icon": "title",
            "name": "Text",
            "key": "T"
        },
        {
            "id": "line",
            "icon": "timeline",
            "name": "Line / curve",
            "key": "O"
        },
        {
            "id": "shape",
            "icon": "interests",
            "name": "Shapes",
            "key": "U"
        }
    ]

    signal chosen(string id)

    title: "Tools"
    implicitWidth: 84
    padding: 6

    GridLayout {
        Layout.alignment: Qt.AlignHCenter
        columns: 2
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: root.tools

            IconButton {
                required property var modelData

                icon: modelData.icon
                size: 34
                iconSize: 21
                iconFill: toggled ? 1 : 0
                toggled: PaintDoc.tool === modelData.id
                onClicked: root.chosen(modelData.id)
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: modelData.name + "  (" + modelData.key + ")"
            }
        }
    }
}
