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

    function focusList() {
        list.forceActiveFocus();
    }

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

        // Up and Down pick the note before or after the open one, Enter takes the editor
        function pick(to) {
            if (rows.length === 0)
                return;
            const at = rows.findIndex(n => n.id === Notes.currentId);
            const next = Math.max(0, Math.min(rows.length - 1, to !== undefined ? to : at));
            Notes.select(rows[next].id);
            const top = next * (rowHeight + gap);
            if (top < contentY)
                contentY = top;
            else if (top + rowHeight > contentY + height)
                contentY = top + rowHeight - height;
        }

        activeFocusOnTab: true
        Keys.onShortcutOverride: event => {
            if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Home, Qt.Key_End, Qt.Key_Return, Qt.Key_Enter].indexOf(event.key) >= 0)
                event.accepted = true;
        }
        Keys.onPressed: event => {
            const at = rows.findIndex(n => n.id === Notes.currentId);
            if (event.key === Qt.Key_Up)
                pick(Math.max(0, at - 1));
            else if (event.key === Qt.Key_Down)
                pick(at + 1);
            else if (event.key === Qt.Key_Home)
                pick(0);
            else if (event.key === Qt.Key_End)
                pick(rows.length - 1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.noteOpened();
            else
                return;
            event.accepted = true;
        }

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

                    FocusRing {
                        gap: 0
                        radius: 8
                        ringColor: Appearance.fgColor
                        visible: row.active && list.activeFocus
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
