import ".."
import QtQuick

// Draws a text layer's text off screen and saves it as a picture for the engine, which composites it.
// The same properties drive the live editor, so what is typed and what ends up on the layer look alike.
Item {
    id: root

    property var props: ({})
    property int pendingId: 0
    property real px: 0
    property real py: 0
    property string layerName: ""
    property int counter: 0

    signal rendered(int id, string path, var props, real x, real y, string name)

    function render(id, p, x, y, name) {
        pendingId = id;
        props = p;
        px = x;
        py = y;
        layerName = name;
        Qt.callLater(grab);
    }

    function grab() {
        holder.grabToImage(result => {
            const path = PaintDoc.tileDir + "/text" + (++counter) + ".png";
            if (result.saveToFile(path))
                rendered(pendingId, path, props, px, py, layerName);
        });
    }

    x: -100000
    y: -100000
    width: 1
    height: 1

    Item {
        id: holder

        width: Math.max(1, Math.ceil(label.implicitWidth))
        height: Math.max(1, Math.ceil(label.implicitHeight))

        Text {
            id: label

            text: root.props.text ?? ""
            color: root.props.color ?? "#000000"
            font.family: root.props.family ?? "Sans Serif"
            font.pixelSize: root.props.size ?? 32
            font.bold: root.props.bold ?? false
            font.italic: root.props.italic ?? false
            font.underline: root.props.underline ?? false
            horizontalAlignment: ({
                    "center": Text.AlignHCenter,
                    "right": Text.AlignRight
                })[root.props.align] ?? Text.AlignLeft
            renderType: Text.QtRendering
        }
    }
}
