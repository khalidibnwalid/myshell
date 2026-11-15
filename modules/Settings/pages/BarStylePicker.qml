import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Pick the look of the bar by seeing it: four small cards, each a miniature screen with the bar
// drawn in that style, in the theme's colours, on the edge the bar really is. The one-line
// description shows when the pointer rests on a card.
Flow {
    id: root

    property string value

    readonly property var styles: [
        {
            "id": "classic",
            "name": "Classic",
            "description": "One strip along the edge"
        },
        {
            "id": "capsule",
            "name": "Capsule",
            "description": "One rounded shape, a little off the edge"
        },
        {
            "id": "islands",
            "name": "Islands",
            "description": "Workspaces, clock and status each in their own shape"
        },
        {
            "id": "inset",
            "name": "Inset",
            "description": "A solid bar, the desktop a rounded sheet beside it"
        }
    ]
    readonly property string position: Config.barPosition
    readonly property bool vertical: position === "left" || position === "right"

    signal picked(string id)

    spacing: 10

    Repeater {
        model: root.styles

        delegate: Rectangle {
            id: card

            required property var modelData
            readonly property bool selected: root.value === modelData.id
            readonly property string kind: modelData.id
            readonly property bool floating: kind === "capsule" || kind === "islands"
            // the bar's room at the edge, scaled down; the floating styles leave a gap to the
            // screen edge only and the shape fills the rest, like the real bar
            readonly property real thick: 14
            readonly property real gap: floating ? 1.2 : 0
            readonly property real wall: kind === "inset" ? 3 : 0

            width: 118
            height: 108
            radius: 14
            color: area.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor
            border.width: selected ? 1.5 : 0
            border.color: Appearance.accentColor

            // the miniature screen
            Rectangle {
                id: screen

                x: 8
                y: 8
                width: parent.width - 16
                height: 70
                radius: 8
                clip: true
                color: card.kind === "inset" ? Appearance.bgColor : "transparent"
                gradient: card.kind === "inset" ? null : sky

                Gradient {
                    id: sky

                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0
                        color: Qt.darker(Appearance.accentColor, 2.8)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.darker(Appearance.accentColor, 4.4)
                    }
                }

                // the desktop: on Inset a rounded sheet beside the solid bar
                Rectangle {
                    visible: card.kind === "inset"
                    x: root.position === "left" ? card.thick : card.wall
                    y: root.position === "top" ? card.thick : card.wall
                    width: screen.width - (root.vertical ? card.thick + card.wall : card.wall * 2)
                    height: screen.height - (root.vertical ? card.wall * 2 : card.thick + card.wall)
                    radius: 6
                    gradient: sky
                }

                // a window
                Rectangle {
                    x: (root.position === "left" ? card.thick : 0) + 9
                    y: (root.position === "top" ? card.thick : 0) + 9
                    width: screen.width - (root.vertical ? card.thick : 0) - 18
                    height: screen.height - (root.vertical ? 0 : card.thick) - 18
                    radius: 4
                    color: Qt.alpha(Appearance.bgColor, 0.6)
                    border.width: 1
                    border.color: Qt.alpha(Appearance.fgColor, 0.12)
                }

                // the bar, on its edge
                Item {
                    id: strip

                    anchors.left: root.position === "right" ? undefined : parent.left
                    anchors.right: root.position === "left" ? undefined : parent.right
                    anchors.top: root.position === "bottom" ? undefined : parent.top
                    anchors.bottom: root.position === "top" ? undefined : parent.bottom
                    width: root.vertical ? card.thick : parent.width
                    height: root.vertical ? parent.height : card.thick

                    // gap to the screen edge only (and at both ends along the bar)
                    readonly property real mLeft: root.vertical ? (root.position === "left" ? card.gap : 0) : card.gap
                    readonly property real mRight: root.vertical ? (root.position === "right" ? card.gap : 0) : card.gap
                    readonly property real mTop: root.vertical ? card.gap : (root.position === "top" ? card.gap : 0)
                    readonly property real mBottom: root.vertical ? card.gap : (root.position === "bottom" ? card.gap : 0)

                    // Classic, Inset: the whole strip. Capsule: one rounded shape.
                    Rectangle {
                        visible: card.kind !== "islands"
                        x: strip.mLeft
                        y: strip.mTop
                        width: strip.width - strip.mLeft - strip.mRight
                        height: strip.height - strip.mTop - strip.mBottom
                        radius: card.kind === "capsule" ? Math.min(width, height) / 2 : 0
                        color: card.kind === "inset" ? Appearance.bgColor : Qt.alpha(Appearance.bgColor, 0.82)
                        border.width: card.kind === "capsule" ? 1 : 0
                        border.color: Qt.alpha(Appearance.fgColor, 0.14)
                    }

                    // the rounded shape behind each group, on Islands
                    Repeater {
                        model: [startGroup, clockGroup, endGroup]

                        delegate: Rectangle {
                            required property var modelData

                            visible: card.kind === "islands"
                            x: root.vertical ? strip.mLeft : modelData.x - 3
                            y: root.vertical ? modelData.y - 3 : strip.mTop
                            width: root.vertical ? strip.width - strip.mLeft - strip.mRight : modelData.width + 6
                            height: root.vertical ? modelData.height + 6 : strip.height - strip.mTop - strip.mBottom
                            radius: Math.min(width, height) / 2
                            color: Qt.alpha(Appearance.bgColor, 0.82)
                            border.width: 1
                            border.color: Qt.alpha(Appearance.fgColor, 0.14)
                        }
                    }

                    // the shape's centre across the bar, so the marks sit in the shape and not in the room
                    readonly property real shiftX: root.vertical ? (mLeft - mRight) / 2 : 0
                    readonly property real shiftY: root.vertical ? 0 : (mTop - mBottom) / 2

                    GridLayout {
                        id: startGroup

                        columns: root.vertical ? 1 : -1
                        rowSpacing: 2.5
                        columnSpacing: 2.5
                        x: root.vertical ? (strip.width - width) / 2 + strip.shiftX : 6
                        y: root.vertical ? 6 : (strip.height - height) / 2 + strip.shiftY

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                            w: 6
                            h: 6
                            tone: Appearance.fgColor
                            opacity: 0.3
                        }

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                            w: root.vertical ? 5 : 9
                            h: root.vertical ? 9 : 5
                            tone: Appearance.accentColor
                            opacity: 1
                        }

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                        }

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                        }
                    }

                    GridLayout {
                        id: clockGroup

                        columns: root.vertical ? 1 : -1
                        rowSpacing: 1.5
                        columnSpacing: 1.5
                        x: root.vertical ? (strip.width - width) / 2 + strip.shiftX : (strip.width - width) / 2
                        y: root.vertical ? (strip.height - height) / 2 : (strip.height - height) / 2 + strip.shiftY

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                            w: 6
                            h: 2
                            tone: Appearance.fgColor
                            opacity: 1
                        }

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                            w: 6
                            h: 2
                            tone: Appearance.accentColor
                            opacity: 1
                        }

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                            w: 4
                            h: 1.5
                            opacity: 0.5
                        }
                    }

                    GridLayout {
                        id: endGroup

                        columns: root.vertical ? 1 : -1
                        rowSpacing: 2.5
                        columnSpacing: 2.5
                        x: root.vertical ? (strip.width - width) / 2 + strip.shiftX : strip.width - width - 6
                        y: root.vertical ? strip.height - height - 6 : (strip.height - height) / 2 + strip.shiftY

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                        }

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                        }

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                        }

                        MiniMark {
                            Layout.alignment: Qt.AlignCenter
                            w: 5
                            h: 5
                            opacity: 0.45
                        }
                    }
                }
            }

            StyledText {
                x: 12
                y: 84
                text: card.modelData.name
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            MaterialSymbol {
                visible: card.selected
                x: parent.width - width - 10
                y: 83
                icon: "check_circle"
                fill: 1
                font.pixelSize: 16
                color: Appearance.accentColor
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(card.modelData.id)
            }

            ToolTip.visible: area.containsMouse
            ToolTip.delay: 500
            ToolTip.text: card.modelData.description
        }
    }
}
