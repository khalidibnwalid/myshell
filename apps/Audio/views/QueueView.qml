import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The queue: the track that plays, and the ones to come, dragged into order by the handle on the left.
ColumnLayout {
    spacing: 8

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: Player.queue.length === 0 ? "The queue is empty" : (Player.queue.length + " tracks, " + Math.max(0, Player.queue.length - Player.index - 1) + " to go")
            color: Appearance.mutedColor
            font.pixelSize: 13
        }

        IconButton {
            visible: Player.queue.length > 0
            icon: "delete_sweep"
            size: 32
            iconSize: 20
            onClicked: Player.clearQueue()
        }
    }

    Flickable {
        id: queueView

        readonly property int rowHeight: 52
        readonly property int step: rowHeight + 2
        // slots[i] is the place the track now at i takes while one is dragged
        property var slots: []
        property int dragged: -1

        function reset() {
            const s = [];
            for (let i = 0; i < Player.queue.length; i++)
                s.push(i);
            slots = s;
        }

        function moveTo(from, target) {
            const next = slots.slice();
            const old = next[from];
            for (let i = 0; i < next.length; i++) {
                if (i === from)
                    continue;
                if (old < target && next[i] > old && next[i] <= target)
                    next[i] -= 1;
                else if (old > target && next[i] < old && next[i] >= target)
                    next[i] += 1;
            }
            next[from] = target;
            slots = next;
        }

        function finish() {
            const order = [];
            for (let i = 0; i < slots.length; i++)
                order[slots[i]] = i;
            dragged = -1;
            if (order.some((o, at) => o !== at))
                Player.reorder(order);
            else
                reset();
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: Player.queue.length * step
        interactive: dragged < 0
        boundsBehavior: Flickable.StopAtBounds
        Component.onCompleted: reset()

        Connections {
            function onQueueChanged() {
                queueView.reset();
            }

            target: Player
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Repeater {
            model: Player.queue.length

            delegate: Item {
                id: qrow

                required property int index
                readonly property string path: Player.queue[index] ?? ""
                readonly property var track: Library.byPath[path] ?? Library.track(path)
                readonly property bool current: index === Player.index
                readonly property bool dragging: queueView.dragged === index
                property real dragY: 0

                width: queueView.width - 8
                height: queueView.rowHeight
                y: dragging ? dragY : (queueView.slots[index] ?? index) * queueView.step
                z: dragging ? 2 : 0

                Behavior on y {
                    enabled: !qrow.dragging
                    NumberAnimation {
                        duration: Appearance.animFast
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: qrow.dragging ? Appearance.surfaceHighColor : (qrow.current ? Qt.alpha(Appearance.accentColor, 0.18) : (rowHover.hovered ? Appearance.surfaceHighColor : "transparent"))
                }

                HoverHandler {
                    id: rowHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Player.jump(qrow.index)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 8
                    spacing: 8

                    Item {
                        Layout.preferredWidth: 28
                        Layout.fillHeight: true

                        MaterialSymbol {
                            anchors.centerIn: parent
                            icon: "drag_indicator"
                            font.pixelSize: 20
                            color: Appearance.mutedColor
                        }

                        MouseArea {
                            id: grip

                            property real grab: 0

                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            onPressed: mouse => {
                                const p = grip.mapToItem(queueView.contentItem, mouse.x, mouse.y);
                                grab = p.y - qrow.y;
                                qrow.dragY = qrow.y;
                                queueView.dragged = qrow.index;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed)
                                    return;
                                const p = grip.mapToItem(queueView.contentItem, mouse.x, mouse.y);
                                const max = (Player.queue.length - 1) * queueView.step;
                                qrow.dragY = Math.max(0, Math.min(max, p.y - grab));
                                const target = Math.round(qrow.dragY / queueView.step);
                                if (target !== queueView.slots[qrow.index])
                                    queueView.moveTo(qrow.index, target);
                            }
                            onReleased: queueView.finish()
                            onCanceled: queueView.finish()
                        }
                    }

                    Cover {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 8
                        source: qrow.track.cover
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: qrow.track.title
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            font.weight: qrow.current ? Font.Bold : Font.Medium
                            color: qrow.current ? Appearance.accentColor : Appearance.fgColor
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qrow.track.artist || "Unknown artist"
                            elide: Text.ElideRight
                            font.pixelSize: 11
                            color: Appearance.mutedColor
                        }
                    }

                    IconButton {
                        visible: rowHover.hovered && !qrow.dragging
                        icon: "close"
                        size: 28
                        iconSize: 18
                        onClicked: Player.removeAt(qrow.index)
                    }
                }
            }
        }
    }
}
