import ".."
import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The list of what was done. Click a step to go back (or forward) to it.
ToolPanel {
    id: root

    title: "History"
    headerActions: [
        IconButton {
            icon: "undo"
            size: 26
            iconSize: 17
            enabled: PaintDoc.hi > 0
            onClicked: PaintDoc.send({
                "op": "undo"
            })
        },
        IconButton {
            icon: "redo"
            size: 26
            iconSize: 17
            enabled: PaintDoc.hi < PaintDoc.hist.length - 1
            onClicked: PaintDoc.send({
                "op": "redo"
            })
        }
    ]

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 50
        clip: true
        spacing: 2
        model: PaintDoc.hist
        boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: true
        keyNavigationEnabled: false
        onCountChanged: Qt.callLater(() => positionViewAtEnd())
        Keys.onPressed: event => {
            const i = PaintDoc.hi + (event.key === Qt.Key_Up ? -1 : (event.key === Qt.Key_Down ? 1 : 0));
            if (i !== PaintDoc.hi && i >= 0 && i < PaintDoc.hist.length) {
                PaintDoc.send({
                    "op": "goto",
                    "to": i
                });
                event.accepted = true;
            }
        }
        Keys.onShortcutOverride: event => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down)
                event.accepted = true;
        }

        ScrollBar.vertical: ScrollBar {
        }

        FocusRing {
            gap: -2
        }

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: index === PaintDoc.hi

            width: list.width
            height: 30
            radius: 10
            color: current ? Appearance.accentColor : (area.containsMouse ? Appearance.surfaceHighColor : "transparent")
            opacity: index > PaintDoc.hi ? 0.45 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                MaterialSymbol {
                    icon: row.modelData.icon
                    font.pixelSize: 17
                    color: row.current ? Appearance.accentContrastColor : Appearance.fgColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.label
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    color: row.current ? Appearance.accentContrastColor : Appearance.fgColor
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    list.forceActiveFocus();
                    PaintDoc.send({
                        "op": "goto",
                        "to": row.index
                    });
                }
            }
        }
    }
}
