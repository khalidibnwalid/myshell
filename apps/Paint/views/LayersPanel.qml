import ".."
import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The layers, top one first. Text layers stay text until they are rasterized by an operation that needs pixels.
ToolPanel {
    id: root

    readonly property var shown: PaintDoc.layers.slice().reverse()
    readonly property var blends: [{
        "label": "Normal",
        "value": "normal"
    }, {
        "label": "Multiply",
        "value": "multiply"
    }, {
        "label": "Screen",
        "value": "screen"
    }, {
        "label": "Overlay",
        "value": "overlay"
    }, {
        "label": "Darken",
        "value": "darken"
    }, {
        "label": "Lighten",
        "value": "lighten"
    }, {
        "label": "Add",
        "value": "add"
    }, {
        "label": "Difference",
        "value": "difference"
    }]
    property int renaming: 0
    property int dragId: 0
    property real dragY: 0
    property real dragStart: 0
    readonly property int step: 48

    // the layer ids top first; while one is dragged it sits in the slot under the pointer
    function order() {
        const ids = shown.map((l) => {
            return l.id;
        });
        if (dragId === 0)
            return ids;

        ids.splice(ids.indexOf(dragId), 1);
        ids.splice(Math.max(0, Math.min(ids.length, Math.round(dragY / step))), 0, dragId);
        return ids;
    }

    function slotOf(id) {
        return order().indexOf(id);
    }

    function beginDrag(id, y) {
        dragId = id;
        dragStart = y;
        dragY = y;
        PaintDoc.select(id);
    }

    function endDrag() {
        const id = dragId;
        if (id === 0)
            return ;

        const from = shown.findIndex((l) => {
            return l.id === id;
        });
        const to = order().indexOf(id);
        dragId = 0;
        if (to !== from)
            PaintDoc.send({
            "op": "layer",
            "kind": "move",
            "layer": id,
            "to": shown.length - 1 - to
        });

    }

    title: "Layers"
    headerActions: [
        IconButton {
            icon: "add"
            size: 26
            iconSize: 17
            onClicked: PaintDoc.layerOp("add")
            ToolTip.visible: hovered
            ToolTip.text: "Add layer  (Ctrl+Shift+N)"
        },
        IconButton {
            icon: "content_copy"
            size: 26
            iconSize: 16
            onClicked: PaintDoc.layerOp("dup")
            ToolTip.visible: hovered
            ToolTip.text: "Duplicate layer"
        },
        IconButton {
            icon: "arrow_upward"
            size: 26
            iconSize: 16
            onClicked: PaintDoc.layerOp("up")
            ToolTip.visible: hovered
            ToolTip.text: "Move layer up"
        },
        IconButton {
            icon: "arrow_downward"
            size: 26
            iconSize: 16
            onClicked: PaintDoc.layerOp("down")
            ToolTip.visible: hovered
            ToolTip.text: "Move layer down"
        },
        IconButton {
            icon: "merge"
            size: 26
            iconSize: 16
            onClicked: PaintDoc.layerOp("merge")
            ToolTip.visible: hovered
            ToolTip.text: "Merge layer down"
        },
        IconButton {
            icon: "delete"
            size: 26
            iconSize: 16
            onClicked: PaintDoc.layerOp("delete")
            ToolTip.visible: hovered
            ToolTip.text: "Delete layer"
        }
    ]

    Flickable {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 56
        clip: true
        contentHeight: root.shown.length * root.step
        interactive: root.dragId === 0
        boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: true
        Keys.onPressed: (event) => {
            const at = root.shown.findIndex((l) => {
                return l.id === PaintDoc.activeId;
            });
            const to = at + (event.key === Qt.Key_Down ? 1 : (event.key === Qt.Key_Up ? -1 : 0));
            if (to !== at && to >= 0 && to < root.shown.length) {
                PaintDoc.select(root.shown[to].id);
                event.accepted = true;
            } else if (event.key === Qt.Key_Space && at >= 0) {
                PaintDoc.setLayer(root.shown[at].id, {
                    "visible": !root.shown[at].visible
                });
                event.accepted = true;
            } else if (event.key === Qt.Key_F2 && at >= 0) {
                root.renaming = root.shown[at].id;
                event.accepted = true;
            }
        }
        Keys.onShortcutOverride: (event) => {
            if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Space, Qt.Key_F2].indexOf(event.key) >= 0)
                event.accepted = true;

        }

        FocusRing {
            gap: -2
        }

        Repeater {
            model: root.shown

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property bool current: modelData.id === PaintDoc.activeId
                readonly property bool dragging: root.dragId === modelData.id

                width: list.width
                height: 46
                x: 0
                y: dragging ? root.dragY : root.slotOf(modelData.id) * root.step
                z: dragging ? 10 : 1
                opacity: dragging ? 0.9 : 1
                radius: 12
                color: current ? Qt.alpha(Appearance.accentColor, 0.28) : (area.containsMouse ? Appearance.surfaceHighColor : "transparent")
                border.width: current ? 1 : 0
                border.color: Appearance.accentColor

                DragHandler {
                    target: null
                    xAxis.enabled: false
                    cursorShape: Qt.ClosedHandCursor
                    onActiveChanged: {
                        if (active)
                            root.beginDrag(row.modelData.id, row.y);
                        else
                            root.endDrag();
                    }
                    onTranslationChanged: {
                        if (active)
                            root.dragY = Math.max(0, Math.min((root.shown.length - 1) * root.step, root.dragStart + translation.y));

                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        list.forceActiveFocus();
                        PaintDoc.select(row.modelData.id);
                    }
                    onDoubleClicked: root.renaming = row.modelData.id
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 8
                    spacing: 6

                    IconButton {
                        icon: row.modelData.visible ? "visibility" : "visibility_off"
                        size: 28
                        iconSize: 17
                        activeFocusOnTab: false
                        onClicked: PaintDoc.setLayer(row.modelData.id, {
                            "visible": !row.modelData.visible
                        })
                    }

                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 36
                        radius: 6
                        clip: true
                        color: Appearance.surfaceColor
                        border.width: 1
                        border.color: Appearance.hairlineColor

                        Image {
                            anchors.fill: parent
                            source: "../checker.svg"
                            fillMode: Image.Tile
                            sourceSize: Qt.size(12, 12)
                            visible: row.modelData.kind === "raster"
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: row.modelData.kind === "raster" && row.modelData.thumb !== ""
                            source: row.modelData.thumb !== "" ? "file://" + row.modelData.thumb : ""
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            smooth: false
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: row.modelData.kind === "text"
                            icon: "title"
                            font.pixelSize: 22
                            color: Appearance.fgColor
                        }

                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            visible: root.renaming !== row.modelData.id
                            Layout.fillWidth: true
                            text: row.modelData.name
                            font.pixelSize: 13
                            font.weight: row.current ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: root.renaming !== row.modelData.id
                            text: (row.modelData.kind === "text" ? "Text · " : "") + Math.round(row.modelData.opacity * 100) + "%" + (row.modelData.blend !== "normal" ? " · " + row.modelData.blend : "")
                            font.pixelSize: 11
                            color: Appearance.mutedColor
                        }

                        FieldInput {
                            id: renameField

                            visible: root.renaming === row.modelData.id
                            Layout.fillWidth: true
                            value: row.modelData.name
                            onVisibleChanged: {
                                if (visible) {
                                    focusInput();
                                    selectAll();
                                }
                            }
                            onCommitted: (text) => {
                                if (text.trim() !== "")
                                    PaintDoc.setLayer(row.modelData.id, {
                                    "name": text.trim()
                                });

                                root.renaming = 0;
                            }
                            onAccepted: root.renaming = 0
                        }

                    }

                }

                Behavior on y {
                    enabled: !row.dragging

                    NumberAnimation {
                        duration: Appearance.animFast
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        ScrollBar.vertical: ScrollBar {
        }

    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: PaintDoc.active !== null
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PillSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                icon: "opacity"
                value: PaintDoc.active ? PaintDoc.active.opacity : 1
                onDragged: (v) => {
                    PaintDoc.setLayer(PaintDoc.activeId, {
                        "opacity": v
                    }, false);
                    opacityDone.restart();
                }
            }

            StyledText {
                text: Math.round((PaintDoc.active ? PaintDoc.active.opacity : 1) * 100) + "%"
                font.pixelSize: 12
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }

        }

        Dropdown {
            Layout.fillWidth: true
            model: root.blends
            value: PaintDoc.active ? PaintDoc.active.blend : "normal"
            popupWidth: 200
            onSelected: (v) => {
                return PaintDoc.setLayer(PaintDoc.activeId, {
                    "blend": v
                });
            }
        }

    }

    Timer {
        id: opacityDone

        interval: 400
        onTriggered: PaintDoc.setLayer(PaintDoc.activeId, {
            "opacity": PaintDoc.active ? PaintDoc.active.opacity : 1
        })
    }

}
