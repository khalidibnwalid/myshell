import "../../../components"
import "../../../config"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The notes as rows that can be dragged into order (pinned ones first); a click picks one, the x removes it.
Item {
    id: root

    property string query: ""

    // a note was picked: the editor takes the keyboard
    signal noteOpened

    Layout.fillWidth: true
    Layout.fillHeight: true

    Flickable {
        id: list

        readonly property var rows: {
            Notes.notes;
            return Notes.sorted(root.query);
        }
        // the order shown while a row is dragged; the rows follow it by slot
        property var order: rows.map(n => n.id)
        readonly property int rowHeight: 52
        readonly property int gap: 3
        property bool dragging: false

        anchors.fill: parent
        clip: true
        contentHeight: Math.max(0, rows.length * (rowHeight + gap) - gap)
        boundsBehavior: Flickable.StopAtBounds
        // the page must not scroll while a note is being dragged
        interactive: !dragging
        onRowsChanged: order = rows.map(n => n.id)

        Item {
            width: list.width
            height: list.contentHeight

            Repeater {
                model: list.rows

                delegate: ListRow {
                    id: row

                    required property var modelData
                    readonly property int slot: list.order.indexOf(modelData.id)
                    property bool dragging: false
                    property real dragY: 0

                    width: list.width
                    implicitHeight: list.rowHeight
                    y: dragging ? dragY : slot * (list.rowHeight + list.gap)
                    z: dragging ? 10 : 0
                    scale: dragging ? 1.02 : 1
                    first: slot === 0
                    last: slot === list.rows.length - 1
                    active: modelData.id === Notes.currentId
                    icon: modelData.pinned ? "push_pin" : ""
                    iconFill: 1
                    title: Notes.titleOf(modelData)
                    subtitle: Notes.previewOf(modelData)
                    // room for the x, so the title never runs under it
                    trailingSpace: 22
                    onClicked: {
                        Notes.select(modelData.id);
                        root.noteOpened();
                    }

                    Behavior on y {
                        enabled: !row.dragging

                        NumberAnimation {
                            duration: Appearance.animFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    // drag a note to move it (not while a search narrows the list)
                    DragHandler {
                        id: drag

                        property real startY: 0

                        target: null
                        xAxis.enabled: false
                        enabled: root.query === ""
                        onActiveChanged: {
                            if (active) {
                                startY = row.y;
                                row.dragY = row.y;
                                row.dragging = true;
                                list.dragging = true;
                            } else {
                                row.dragging = false;
                                list.dragging = false;
                                Notes.reorder(list.order);
                            }
                        }
                        onTranslationChanged: {
                            if (!active)
                                return;
                            const step = list.rowHeight + list.gap;
                            const bottom = (list.rows.length - 1) * step;
                            row.dragY = Math.max(0, Math.min(bottom, startY + translation.y));
                            const want = Math.max(0, Math.min(list.rows.length - 1, Math.round(row.dragY / step)));
                            const have = list.order.indexOf(row.modelData.id);
                            if (want !== have) {
                                const next = list.order.slice();
                                next.splice(have, 1);
                                next.splice(want, 0, row.modelData.id);
                                list.order = next;
                            }
                        }
                    }

                    // x at the end of the row while it is hovered: deletes the note
                    IconButton {
                        id: removeButton

                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (row.hovered || removeButton.hovered) && !row.dragging
                        icon: "close"
                        size: 28
                        iconSize: 16
                        color: row.contentColor
                        onClicked: Notes.remove(row.modelData.id)
                    }
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: list.rows.length === 0
        text: root.query === "" ? "No notes yet" : "No note matches"
        color: Appearance.mutedColor
    }
}
