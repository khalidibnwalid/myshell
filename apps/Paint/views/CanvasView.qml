import ".."
import "../../../config"
import QtQuick

// The picture on the screen: the tiles the engine writes, the selection, the overlay, and the pointer and
// wheel. A point in the document (x, y) is at (panX + x * zoom, panY + y * zoom) in this item.
Item {
    id: root

    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property alias handler: tools
    readonly property int tilesX: Math.max(1, Math.ceil(PaintDoc.docW / 256))
    readonly property int tilesY: Math.max(1, Math.ceil(PaintDoc.docH / 256))

    function docX(sx) {
        return (sx - panX) / zoom;
    }

    function docY(sy) {
        return (sy - panY) / zoom;
    }

    function zoomAt(sx, sy, factor) {
        const z = Math.max(0.05, Math.min(64, zoom * factor));
        panX = sx - (sx - panX) * z / zoom;
        panY = sy - (sy - panY) * z / zoom;
        zoom = z;
    }

    function zoomCentered(factor) {
        zoomAt(width / 2, height / 2, factor);
    }

    function panBy(dx, dy) {
        panX += dx;
        panY += dy;
    }

    function zoomFit() {
        if (PaintDoc.docW < 1 || width < 1)
            return;
        zoom = Math.max(0.05, Math.min(8, Math.min((width - 48) / PaintDoc.docW, (height - 48) / PaintDoc.docH)));
        center();
    }

    function zoomActual() {
        zoom = 1;
        center();
    }

    function center() {
        panX = (width - PaintDoc.docW * zoom) / 2;
        panY = (height - PaintDoc.docH * zoom) / 2;
    }

    clip: true
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
            tools.spaceDown = true;
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
            tools.spaceDown = false;
            event.accepted = true;
        }
    }
    Keys.onShortcutOverride: event => {
        if (event.key === Qt.Key_Space)
            event.accepted = true;
    }

    Connections {
        function onReset() {
            Qt.callLater(root.zoomFit);
        }

        target: PaintDoc
    }

    ToolHandler {
        id: tools

        view: root
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Appearance.fgColor, 0.05)
    }

    Item {
        x: root.panX
        y: root.panY
        width: PaintDoc.docW * root.zoom
        height: PaintDoc.docH * root.zoom
        clip: true

        Image {
            anchors.fill: parent
            source: "../checker.svg"
            fillMode: Image.Tile
            sourceSize: Qt.size(16, 16)
        }
    }

    Item {
        id: world

        x: root.panX
        y: root.panY
        width: PaintDoc.docW
        height: PaintDoc.docH
        scale: root.zoom
        transformOrigin: Item.TopLeft

        Repeater {
            model: root.tilesX * root.tilesY

            TileImage {
                required property int index
                readonly property int tx: index % root.tilesX
                readonly property int ty: Math.floor(index / root.tilesX)
                readonly property int ver: PaintDoc.tileVer[tx + "_" + ty] ?? 0

                x: tx * 256
                y: ty * 256
                source: ver > 0 ? "file://" + PaintDoc.tileDir + "/t" + tx + "_" + ty + "_" + ver + ".png" : ""
                smooth: root.zoom < 1
            }
        }

        TileImage {
            visible: PaintDoc.sel !== null
            source: PaintDoc.sel ? "file://" + PaintDoc.sel.url : ""
            smooth: false
        }
    }

    OverlayCanvas {
        handler: tools
        zoom: root.zoom
        panX: root.panX
        panY: root.panY
    }

    MouseArea {
        id: area

        function pos(m) {
            return [root.docX(m.x), root.docY(m.y)];
        }

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: tools.spaceDown || tools.tool === "pan" ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : (tools.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor)
        onPressed: mouse => {
            root.forceActiveFocus();
            const p = pos(mouse);
            tools.press(p[0], p[1], mouse.button, mouse.modifiers, mouse.x, mouse.y);
        }
        onPositionChanged: mouse => {
            const p = pos(mouse);
            if (pressed)
                tools.move(p[0], p[1], mouse.buttons, mouse.modifiers, mouse.x, mouse.y);
            else
                tools.hover(p[0], p[1]);
        }
        onReleased: mouse => {
            const p = pos(mouse);
            tools.release(p[0], p[1], mouse.button, mouse.modifiers);
        }
        onExited: tools.cursor = Qt.point(-1, -1)
        onWheel: wheel => {
            if (wheel.modifiers & Qt.ControlModifier) {
                root.zoomAt(wheel.x, wheel.y, wheel.angleDelta.y > 0 ? 1.15 : 1 / 1.15);
            } else if (wheel.modifiers & Qt.ShiftModifier) {
                root.panBy(wheel.angleDelta.y > 0 ? 60 : -60, 0);
            } else {
                root.panBy(wheel.angleDelta.x, wheel.angleDelta.y);
            }
        }
    }

    // the text being typed, drawn where it will sit
    Rectangle {
        visible: tools.editId > 0
        x: root.panX + tools.editX * root.zoom - 3
        y: root.panY + tools.editY * root.zoom - 3
        width: editor.width + 6
        height: editor.height + 6
        color: "transparent"
        border.width: 1
        border.color: "#1a73e8"

        TextEdit {
            id: editor

            x: 3
            y: 3
            width: Math.max(contentWidth, 12) + 8
            color: PaintDoc.primary
            font.family: PaintDoc.textFamily
            font.pixelSize: PaintDoc.textSize * root.zoom
            font.bold: PaintDoc.textBold
            font.italic: PaintDoc.textItalic
            font.underline: PaintDoc.textUnderline
            horizontalAlignment: ({
                    "center": TextEdit.AlignHCenter,
                    "right": TextEdit.AlignRight
                })[PaintDoc.textAlign] ?? TextEdit.AlignLeft
            selectByMouse: true
            persistentSelection: true
            onTextChanged: if (tools.editId > 0 && text !== tools.editText)
                tools.editText = text
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                    tools.commitText();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    tools.cancelText();
                    root.forceActiveFocus();
                    event.accepted = true;
                }
            }

            Connections {
                function onEditIdChanged() {
                    if (tools.editId > 0) {
                        editor.text = tools.editText;
                        editor.forceActiveFocus();
                        editor.cursorPosition = editor.text.length;
                    }
                }

                target: tools
            }
        }
    }
}
