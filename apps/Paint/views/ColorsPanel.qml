import ".."
import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Primary and secondary colour. Click a swatch to choose which one the wheel edits; in the palette, left click
// sets the primary colour and right click the secondary.
ToolPanel {
    id: root

    readonly property var swatches: ["#000000", "#404040", "#808080", "#c0c0c0", "#ffffff", "#ff0000", "#ff7f00", "#ffd800", "#7fff00", "#00c000", "#00d8d8", "#0080ff", "#0000ff", "#7f00ff", "#ff00ff", "#ff007f", "#7f0000", "#7f3f00", "#7f6c00", "#3f7f00", "#006000", "#006c6c", "#00407f", "#00007f", "#3f007f", "#7f007f", "#7f003f", "#c47a4a", "#f2c9a0", "#a0c4f2", "#c0f2a0", "#f2a0c4"]
    property bool editSecondary: false

    title: "Colors"

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Item {
            Layout.preferredWidth: 78
            Layout.preferredHeight: 62

            Rectangle {
                x: 24
                y: 20
                width: 48
                height: 38
                radius: 8
                color: PaintDoc.secondary
                border.width: 2
                border.color: root.editSecondary ? Appearance.accentColor : Appearance.outlineColor

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editSecondary = true
                }
            }

            Rectangle {
                x: 2
                y: 2
                width: 48
                height: 38
                radius: 8
                color: PaintDoc.primary
                border.width: 2
                border.color: root.editSecondary ? Appearance.outlineColor : Appearance.accentColor

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editSecondary = false
                }
            }
        }

        ColumnLayout {
            spacing: 0

            IconButton {
                icon: "swap_horiz"
                size: 30
                iconSize: 18
                onClicked: {
                    const p = PaintDoc.primary;
                    PaintDoc.primary = PaintDoc.secondary;
                    PaintDoc.secondary = p;
                }
                ToolTip.visible: hovered
                ToolTip.text: "Swap colors  (X)"
            }

            IconButton {
                icon: "restart_alt"
                size: 30
                iconSize: 18
                onClicked: {
                    PaintDoc.primary = "#000000";
                    PaintDoc.secondary = "#ffffff";
                }
                ToolTip.visible: hovered
                ToolTip.text: "Black and white"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                text: "Opacity"
                font.pixelSize: 11
                color: Appearance.mutedColor
            }

            PillSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                icon: "opacity"
                value: PaintDoc.primary.a
                onDragged: v => PaintDoc.primary = Qt.rgba(PaintDoc.primary.r, PaintDoc.primary.g, PaintDoc.primary.b, v)
            }
        }
    }

    ColorWheel {
        Layout.fillWidth: true
        wheelSize: 124
        color: root.editSecondary ? PaintDoc.secondary : PaintDoc.primary
        onEdited: c => {
            if (root.editSecondary)
                PaintDoc.secondary = c;
            else
                PaintDoc.primary = c;
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 16
        rowSpacing: 3
        columnSpacing: 3

        Repeater {
            model: root.swatches

            Rectangle {
                required property string modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 14
                radius: 4
                color: modelData
                border.width: 1
                border.color: Appearance.hairlineColor

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const a = PaintDoc.primary.a;
                        if (mouse.button === Qt.RightButton)
                            PaintDoc.secondary = modelData;
                        else
                            PaintDoc.primary = Qt.rgba(Qt.color(modelData).r, Qt.color(modelData).g, Qt.color(modelData).b, a);
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: PaintDoc.recents.length > 0
        spacing: 3

        Repeater {
            model: PaintDoc.recents

            Rectangle {
                required property string modelData

                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: modelData
                border.width: 1
                border.color: Appearance.outlineColor

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => mouse.button === Qt.RightButton ? PaintDoc.secondary = modelData : PaintDoc.primary = modelData
                }
            }
        }
    }
}
