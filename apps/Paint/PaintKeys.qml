import QtQuick

// The shortcuts of the Paint window. A plain letter chooses a tool; a text field that has the focus keeps
// its own letters.
Item {
    id: root

    property var window: null
    property var actions: null
    property var canvas: null

    function key(seq, fn) {
        return seq;
    }

    Instantiator {
        model: [
            ["Ctrl+N", "new"],
            ["Ctrl+O", "open"],
            ["Ctrl+S", "save"],
            ["Ctrl+Shift+S", "saveAs"],
            ["Ctrl+W", "close"],
            ["Ctrl+Z", "undo"],
            ["Ctrl+Y", "redo"],
            ["Ctrl+Shift+Z", "redo"],
            ["Ctrl+X", "cut"],
            ["Ctrl+C", "copy"],
            ["Ctrl+V", "paste"],
            ["Delete", "clear"],
            ["Backspace", "fillsel"],
            ["Ctrl+A", "selectAll"],
            ["Ctrl+D", "deselect"],
            ["Ctrl+I", "invertSel"],
            ["Ctrl+Shift+X", "crop"],
            ["Ctrl+R", "resize"],
            ["Ctrl+Shift+R", "canvasSize"],
            ["Ctrl+Shift+F", "flatten"],
            ["Ctrl+Shift+N", "layerAdd"],
            ["Ctrl+Shift+D", "layerDup"],
            ["Ctrl+]", "layerUp"],
            ["Ctrl+[", "layerDown"],
            ["Ctrl+M", "layerMerge"],
            ["Ctrl++", "zoomIn"],
            ["Ctrl+=", "zoomIn"],
            ["Ctrl+-", "zoomOut"],
            ["Ctrl+0", "zoomFit"],
            ["Ctrl+1", "zoomActual"]
        ]

        delegate: Shortcut {
            required property var modelData

            sequence: modelData[0]
            onActivated: root.actions.act(modelData[1])
        }
    }

    Instantiator {
        model: [["S", "rectSelect"], ["M", "moveSelected"], ["A", "lasso"], ["N", "moveSel"], ["D", "ellipseSelect"], ["Z", "zoom"], ["W", "wand"], ["H", "pan"], ["F", "bucket"], ["G", "gradient"], ["B", "brush"], ["E", "eraser"], ["P", "pencil"], ["K", "picker"], ["L", "clone"], ["R", "recolor"], ["T", "text"], ["O", "line"], ["U", "shape"]]

        delegate: Shortcut {
            required property var modelData

            sequence: modelData[0]
            onActivated: PaintDoc.tool = modelData[1]
        }
    }

    Shortcut {
        sequence: "X"
        onActivated: {
            const p = PaintDoc.primary;
            PaintDoc.primary = PaintDoc.secondary;
            PaintDoc.secondary = p;
        }
    }

    Shortcut {
        sequence: "["
        onActivated: PaintDoc.brushSize = Math.max(1, PaintDoc.brushSize - (PaintDoc.brushSize > 50 ? 5 : 1))
    }

    Shortcut {
        sequence: "]"
        onActivated: PaintDoc.brushSize = Math.min(500, PaintDoc.brushSize + (PaintDoc.brushSize >= 50 ? 5 : 1))
    }

    Shortcut {
        sequence: "Return"
        onActivated: root.canvas.handler.commitPending()
    }

    Shortcut {
        sequence: "Enter"
        onActivated: root.canvas.handler.commitPending()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            const h = root.canvas.handler;
            if (h.pending)
                h.cancelPending();
            else if (PaintDoc.sel)
                root.actions.act("deselect");
        }
    }
}
