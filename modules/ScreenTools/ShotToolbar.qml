import "../../components"
import "../../config/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The screenshot editor's tools, colours and sizes, in one pill under the image.
Rectangle {
    id: root

    property string tool: ""
    property color penColor: "red"
    property int size: 1
    readonly property var tools: [
        {
            "id": "arrow",
            "icon": "arrow_outward",
            "name": "Arrow",
            "key": "A"
        },
        {
            "id": "rect",
            "icon": "crop_square",
            "name": "Rectangle",
            "key": "R"
        },
        {
            "id": "pen",
            "icon": "stylus",
            "name": "Pen",
            "key": "P"
        },
        {
            "id": "marker",
            "icon": "ink_highlighter",
            "name": "Highlighter",
            "key": "H"
        },
        {
            "id": "text",
            "icon": "title",
            "name": "Text",
            "key": "T"
        },
        {
            "id": "pixelate",
            "icon": "grid_on",
            "name": "Pixelate, to hide a secret",
            "key": "X"
        },
        {
            "id": "blur",
            "icon": "blur_on",
            "name": "Blur",
            "key": "B"
        },
        {
            "id": "crop",
            "icon": "crop",
            "name": "Crop",
            "key": "C"
        }
    ]
    readonly property var colors: ["#ff4d4d", "#ffb020", "#ffe14d", "#3ddc84", "#4d9fff", "#ffffff", "#111111"]

    signal toolChosen(string id)
    signal colorChosen(color value)
    signal sizeChosen(int value)

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 52
    radius: height / 2
    color: Appearance.surfaceColor

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.tools

            IconButton {
                required property var modelData

                icon: modelData.icon
                size: 38
                iconSize: 22
                iconFill: toggled ? 1 : 0
                toggled: root.tool === modelData.id
                onClicked: root.toolChosen(modelData.id)
                Accessible.name: modelData.name
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: modelData.name + "  (" + modelData.key + ")"
            }
        }

        Rectangle {
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitWidth: 1
            implicitHeight: 24
            color: Appearance.hairlineColor
        }

        Repeater {
            model: root.colors

            // a colour swatch; the chosen one has a ring
            Rectangle {
                id: swatch

                required property string modelData
                readonly property bool current: Qt.colorEqual(root.penColor, modelData)

                implicitWidth: 30
                implicitHeight: 30
                radius: 15
                color: "transparent"
                border.width: current ? 2 : 0
                border.color: Appearance.fgColor
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Colour " + modelData
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.colorChosen(swatch.modelData);
                        event.accepted = true;
                    }
                }
                Keys.onShortcutOverride: event => {
                    if (event.key === Qt.Key_Space)
                        event.accepted = true;
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: swatchArea.containsMouse || swatch.current ? 20 : 18
                    height: width
                    radius: width / 2
                    color: swatch.modelData
                    border.width: 1
                    border.color: Appearance.outlineColor
                }

                FocusRing {
                    gap: 1
                }

                MouseArea {
                    id: swatchArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.colorChosen(swatch.modelData)
                }
            }
        }

        Rectangle {
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitWidth: 1
            implicitHeight: 24
            color: Appearance.hairlineColor
        }

        // thin, medium, thick: the lines, the text and the pixelate cells
        Segmented {
            model: [
                {
                    "label": "S",
                    "value": 0
                },
                {
                    "label": "M",
                    "value": 1
                },
                {
                    "label": "L",
                    "value": 2
                }
            ]
            value: root.size
            onSelected: v => root.sizeChosen(v)
            Accessible.name: "Size (1, 2, 3)"
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: "Size  (1, 2, 3)"

            property bool hovered: sizeHover.hovered

            HoverHandler {
                id: sizeHover
            }
        }
    }
}
