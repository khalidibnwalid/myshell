import ".."
import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Menus on the left; undo, redo, save and the close button on the right. Every menu entry is an action key
// that the window handles (PaintActions).
RowLayout {
    id: root

    property bool showTools: true
    property bool showColors: true
    property bool showLayers: true
    property bool showHistory: true

    signal action(string key)
    signal closeRequested

    readonly property bool hasSel: PaintDoc.sel !== null
    readonly property bool raster: PaintDoc.active !== null && PaintDoc.active.kind === "raster"

    spacing: 2

    MenuButton {
        text: "File"
        onTriggered: key => root.action(key)
        model: [
            {
                "label": "New…",
                "key": "new",
                "icon": "note_add",
                "shortcut": "Ctrl+N"
            },
            {
                "label": "Open…",
                "key": "open",
                "icon": "folder_open",
                "shortcut": "Ctrl+O"
            },
            {
                "label": "Open as layer…",
                "key": "import",
                "icon": "add_photo_alternate"
            },
            {
                "separator": true
            },
            {
                "label": "Save",
                "key": "save",
                "icon": "save",
                "shortcut": "Ctrl+S"
            },
            {
                "label": "Save as…",
                "key": "saveAs",
                "icon": "save_as",
                "shortcut": "Ctrl+Shift+S"
            },
            {
                "separator": true
            },
            {
                "label": "Close",
                "key": "close",
                "icon": "close",
                "shortcut": "Ctrl+W"
            }
        ]
    }

    MenuButton {
        text: "Edit"
        onTriggered: key => root.action(key)
        model: [
            {
                "label": "Undo",
                "key": "undo",
                "icon": "undo",
                "shortcut": "Ctrl+Z",
                "enabled": PaintDoc.hi > 0
            },
            {
                "label": "Redo",
                "key": "redo",
                "icon": "redo",
                "shortcut": "Ctrl+Y",
                "enabled": PaintDoc.hi < PaintDoc.hist.length - 1
            },
            {
                "separator": true
            },
            {
                "label": "Cut",
                "key": "cut",
                "icon": "content_cut",
                "shortcut": "Ctrl+X"
            },
            {
                "label": "Copy",
                "key": "copy",
                "icon": "content_copy",
                "shortcut": "Ctrl+C"
            },
            {
                "label": "Paste as new layer",
                "key": "paste",
                "icon": "content_paste",
                "shortcut": "Ctrl+V"
            },
            {
                "label": "Erase selection",
                "key": "clear",
                "icon": "delete_sweep",
                "shortcut": "Delete",
                "enabled": root.raster
            },
            {
                "label": "Fill selection",
                "key": "fillsel",
                "icon": "format_color_fill",
                "shortcut": "Backspace",
                "enabled": root.raster
            },
            {
                "separator": true
            },
            {
                "label": "Select all",
                "key": "selectAll",
                "icon": "select_all",
                "shortcut": "Ctrl+A"
            },
            {
                "label": "Deselect",
                "key": "deselect",
                "icon": "deselect",
                "shortcut": "Ctrl+D",
                "enabled": root.hasSel
            },
            {
                "label": "Invert selection",
                "key": "invertSel",
                "icon": "invert_colors",
                "shortcut": "Ctrl+I",
                "enabled": root.hasSel
            }
        ]
    }

    MenuButton {
        text: "Image"
        onTriggered: key => root.action(key)
        model: [
            {
                "label": "Crop to selection",
                "key": "crop",
                "icon": "crop",
                "shortcut": "Ctrl+Shift+X",
                "enabled": root.hasSel
            },
            {
                "label": "Resize image…",
                "key": "resize",
                "icon": "photo_size_select_large",
                "shortcut": "Ctrl+R"
            },
            {
                "label": "Canvas size…",
                "key": "canvasSize",
                "icon": "aspect_ratio",
                "shortcut": "Ctrl+Shift+R"
            },
            {
                "separator": true
            },
            {
                "label": "Flip horizontal",
                "key": "flipH",
                "icon": "flip"
            },
            {
                "label": "Flip vertical",
                "key": "flipV",
                "icon": "flip"
            },
            {
                "label": "Rotate 90° clockwise",
                "key": "rotate90",
                "icon": "rotate_right"
            },
            {
                "label": "Rotate 90° counter-clockwise",
                "key": "rotate270",
                "icon": "rotate_left"
            },
            {
                "label": "Rotate 180°",
                "key": "rotate180",
                "icon": "refresh"
            },
            {
                "separator": true
            },
            {
                "label": "Flatten",
                "key": "flatten",
                "icon": "layers_clear",
                "shortcut": "Ctrl+Shift+F"
            }
        ]
    }

    MenuButton {
        text: "Layers"
        onTriggered: key => root.action(key)
        model: [
            {
                "label": "Add new layer",
                "key": "layerAdd",
                "icon": "add",
                "shortcut": "Ctrl+Shift+N"
            },
            {
                "label": "Duplicate layer",
                "key": "layerDup",
                "icon": "content_copy",
                "shortcut": "Ctrl+Shift+D"
            },
            {
                "label": "Delete layer",
                "key": "layerDelete",
                "icon": "delete"
            },
            {
                "separator": true
            },
            {
                "label": "Move layer up",
                "key": "layerUp",
                "icon": "arrow_upward",
                "shortcut": "Ctrl+]"
            },
            {
                "label": "Move layer down",
                "key": "layerDown",
                "icon": "arrow_downward",
                "shortcut": "Ctrl+["
            },
            {
                "label": "Merge layer down",
                "key": "layerMerge",
                "icon": "merge",
                "shortcut": "Ctrl+M"
            }
        ]
    }

    MenuButton {
        text: "Adjustments"
        onTriggered: key => root.action(key)
        model: [
            {
                "label": "Invert colors",
                "key": "adj:invert",
                "icon": "invert_colors",
                "enabled": root.raster
            },
            {
                "label": "Black and white",
                "key": "adj:grayscale",
                "icon": "monochrome_photos",
                "enabled": root.raster
            },
            {
                "label": "Sepia",
                "key": "adj:sepia",
                "icon": "filter_vintage",
                "enabled": root.raster
            },
            {
                "separator": true
            },
            {
                "label": "Brightness…",
                "key": "amt:brightness",
                "icon": "brightness_6",
                "enabled": root.raster
            },
            {
                "label": "Contrast…",
                "key": "amt:contrast",
                "icon": "contrast",
                "enabled": root.raster
            },
            {
                "label": "Saturation…",
                "key": "amt:saturation",
                "icon": "water_drop",
                "enabled": root.raster
            },
            {
                "label": "Hue…",
                "key": "amt:hue",
                "icon": "palette",
                "enabled": root.raster
            },
            {
                "label": "Posterize…",
                "key": "amt:posterize",
                "icon": "filter_b_and_w",
                "enabled": root.raster
            }
        ]
    }

    MenuButton {
        text: "Effects"
        onTriggered: key => root.action(key)
        model: [
            {
                "label": "Blur…",
                "key": "amt:blur",
                "icon": "blur_on",
                "enabled": root.raster
            },
            {
                "label": "Sharpen…",
                "key": "amt:sharpen",
                "icon": "deblur",
                "enabled": root.raster
            },
            {
                "label": "Pixelate…",
                "key": "amt:pixelate",
                "icon": "grid_on",
                "enabled": root.raster
            },
            {
                "label": "Add noise…",
                "key": "amt:noise",
                "icon": "grain",
                "enabled": root.raster
            }
        ]
    }

    MenuButton {
        text: "View"
        onTriggered: key => root.action(key)
        model: [
            {
                "label": "Zoom in",
                "key": "zoomIn",
                "icon": "zoom_in",
                "shortcut": "Ctrl++"
            },
            {
                "label": "Zoom out",
                "key": "zoomOut",
                "icon": "zoom_out",
                "shortcut": "Ctrl+-"
            },
            {
                "label": "Fit to window",
                "key": "zoomFit",
                "icon": "fit_screen",
                "shortcut": "Ctrl+0"
            },
            {
                "label": "Actual size",
                "key": "zoomActual",
                "icon": "pin",
                "shortcut": "Ctrl+1"
            },
            {
                "separator": true
            },
            {
                "label": "Tools",
                "key": "panel:tools",
                "icon": root.showTools ? "check" : ""
            },
            {
                "label": "Colors",
                "key": "panel:colors",
                "icon": root.showColors ? "check" : ""
            },
            {
                "label": "Layers",
                "key": "panel:layers",
                "icon": root.showLayers ? "check" : ""
            },
            {
                "label": "History",
                "key": "panel:history",
                "icon": root.showHistory ? "check" : ""
            }
        ]
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: 14
        text: PaintDoc.docName + (PaintDoc.modified ? " •" : "")
        font.pixelSize: 13
        color: Appearance.mutedColor
        elide: Text.ElideMiddle
    }

    Rectangle {
        implicitWidth: badge.implicitWidth + 20
        implicitHeight: 26
        radius: 13
        color: Appearance.surfaceColor

        Row {
            id: badge

            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                icon: "science"
                font.pixelSize: 15
                color: Appearance.mutedColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Experimental"
                font.pixelSize: 12
                color: Appearance.mutedColor
            }
        }

        MouseArea {
            id: badgeArea

            anchors.fill: parent
            hoverEnabled: true
        }

        ToolTip.visible: badgeArea.containsMouse
        ToolTip.text: "Paint is new: some tools may misbehave. Save often (.ora keeps layers)"
    }

    IconButton {
        icon: "undo"
        enabled: PaintDoc.hi > 0
        onClicked: root.action("undo")
        ToolTip.visible: hovered
        ToolTip.text: "Undo  (Ctrl+Z)"
    }

    IconButton {
        icon: "redo"
        enabled: PaintDoc.hi < PaintDoc.hist.length - 1
        onClicked: root.action("redo")
        ToolTip.visible: hovered
        ToolTip.text: "Redo  (Ctrl+Y)"
    }

    IconButton {
        icon: "folder_open"
        onClicked: root.action("open")
        ToolTip.visible: hovered
        ToolTip.text: "Open  (Ctrl+O)"
    }

    IconButton {
        icon: "save"
        onClicked: root.action("save")
        ToolTip.visible: hovered
        ToolTip.text: "Save  (Ctrl+S)"
    }

    IconButton {
        icon: "close"
        onClicked: root.closeRequested()
        ToolTip.visible: hovered
        ToolTip.text: "Close  (Ctrl+W)"
    }
}
