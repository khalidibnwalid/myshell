import "../config/"
import QtQuick
import Quickshell

// A list of rows that can be dragged into a new order. items: [{ id, title, description,
// icon (a Material symbol), image (an app icon, optional) }]. reordered(ids) gives the new
// order when a drag ends.
Item {
    id: root

    property var items: []
    // the order being shown while a row is dragged
    property var order: items.map(i => i.id)
    readonly property int rowHeight: 56
    readonly property int gap: 3

    signal reordered(var ids)

    function iconSource(img) {
        if (!img)
            return "";
        if (img.startsWith("/"))
            return "file://" + img;
        return Quickshell.iconPath(img, true);
    }

    onItemsChanged: order = items.map(i => i.id)

    implicitHeight: Math.max(0, items.length * (rowHeight + gap) - gap)

    Repeater {
        model: root.items

        delegate: Rectangle {
            id: card

            required property var modelData
            readonly property int slot: root.order.indexOf(modelData.id)
            readonly property bool first: slot === 0
            readonly property bool last: slot === root.items.length - 1
            property bool dragging: false
            property real dragY: 0

            width: root.width
            height: root.rowHeight
            y: dragging ? dragY : slot * (root.rowHeight + root.gap)
            z: dragging ? 10 : 0
            color: dragging ? Appearance.surfaceHighColor : Appearance.surfaceColor
            topLeftRadius: first ? 22 : 6
            topRightRadius: first ? 22 : 6
            bottomLeftRadius: last ? 22 : 6
            bottomRightRadius: last ? 22 : 6
            scale: dragging ? 1.015 : 1

            Behavior on y {
                enabled: !card.dragging

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

            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 14

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "drag_indicator"
                    font.pixelSize: 22
                    color: Appearance.mutedColor
                }

                Item {
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: appImage

                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: root.iconSource(card.modelData.image)
                        sourceSize: Qt.size(56, 56)
                        fillMode: Image.PreserveAspectFit
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !appImage.visible
                        icon: card.modelData.icon || "apps"
                        font.pixelSize: 22
                        color: Appearance.fgColor
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 100

                    StyledText {
                        width: parent.width
                        text: card.modelData.title
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                    }

                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: card.modelData.description || ""
                        elide: Text.ElideRight
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                    }
                }
            }

            // the whole row is the handle
            MouseArea {
                id: area

                property real startMouse: 0
                property real startY: 0

                anchors.fill: parent
                // the page behind is a Flickable: it must not take the drag and scroll
                preventStealing: true
                cursorShape: card.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: mouse => {
                    startMouse = mapToItem(root, mouse.x, mouse.y).y;
                    startY = card.y;
                    card.dragY = card.y;
                    card.dragging = true;
                }
                onPositionChanged: mouse => {
                    if (!card.dragging)
                        return;
                    const top = 0;
                    const bottom = (root.items.length - 1) * (root.rowHeight + root.gap);
                    const now = mapToItem(root, mouse.x, mouse.y).y;
                    card.dragY = Math.max(top, Math.min(bottom, startY + now - startMouse));
                    const want = Math.max(0, Math.min(root.items.length - 1, Math.round(card.dragY / (root.rowHeight + root.gap))));
                    const have = root.order.indexOf(card.modelData.id);
                    if (want !== have) {
                        const next = root.order.slice();
                        next.splice(have, 1);
                        next.splice(want, 0, card.modelData.id);
                        root.order = next;
                    }
                }
                onReleased: {
                    card.dragging = false;
                    root.reordered(root.order);
                }
                onCanceled: {
                    card.dragging = false;
                    root.reordered(root.order);
                }
            }
        }
    }
}
