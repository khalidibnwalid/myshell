import QtQuick

// What the pointer does on the canvas for the chosen tool. It takes document coordinates, sends commands to
// the engine and keeps the little state the overlay draws (rubber band, lasso, pending shape, cursor).
Item {
    id: root

    // the canvas view, for zooming and panning
    property var view: null
    property bool spaceDown: false

    // overlay state
    property var rubber: null
    property var lasso: []
    property var pending: null
    property var gradLine: null
    property point cursor: Qt.point(-1, -1)
    property var cloneSrc: null
    // text being typed
    property int editId: 0
    property string editText: ""
    property bool editIsNew: false
    property real editX: 0
    property real editY: 0

    property string mode: ""
    property var start: ({})
    property int handleIdx: -1
    property bool bent: false
    property int pickTarget: 0
    property real lastSx: 0
    property real lastSy: 0
    property var cloneOffset: null

    readonly property string tool: PaintDoc.tool
    readonly property var shapeTools: ["line", "shape"]
    readonly property var drawTools: ["brush", "eraser", "pencil", "clone", "recolor"]

    signal changed
    signal renderText(int id, var props, real x, real y, string name)

    function activeRaster() {
        const a = PaintDoc.active;
        if (!a || a.kind !== "raster") {
            PaintDoc.say("Pick a pixel layer first: text layers are moved with the Move tool and edited with the Text tool");
            return null;
        }
        return a;
    }

    function selModeFor(mods) {
        if (mods & Qt.ControlModifier)
            return "add";
        if (mods & Qt.AltModifier)
            return "subtract";
        return PaintDoc.selMode;
    }

    function colors(button) {
        const swap = button === Qt.RightButton;
        return [PaintDoc.hex8(swap ? PaintDoc.secondary : PaintDoc.primary), PaintDoc.hex8(swap ? PaintDoc.primary : PaintDoc.secondary)];
    }

    function constrain(x0, y0, x, y) {
        const dx = x - x0, dy = y - y0, m = Math.max(Math.abs(dx), Math.abs(dy));
        return [x0 + (dx < 0 ? -m : m), y0 + (dy < 0 ? -m : m)];
    }

    function snapAngle(x0, y0, x, y) {
        const a = Math.round(Math.atan2(y - y0, x - x0) / (Math.PI / 12)) * (Math.PI / 12), l = Math.hypot(x - x0, y - y0);
        return [x0 + Math.cos(a) * l, y0 + Math.sin(a) * l];
    }

    function press(x, y, button, mods, sx, sy) {
        lastSx = sx;
        lastSy = sy;
        if (button === Qt.MiddleButton || spaceDown || tool === "pan") {
            mode = "pan";
            return;
        }
        if (editId > 0 && tool !== "text")
            commitText();
        if (tool !== "text" && editId > 0)
            return;
        switch (tool) {
        case "rectSelect":
        case "ellipseSelect":
            rubber = {
                "x0": x,
                "y0": y,
                "x1": x,
                "y1": y,
                "ellipse": tool === "ellipseSelect",
                "mode": selModeFor(mods)
            };
            mode = "rubber";
            break;
        case "lasso":
            lasso = [[x, y]];
            start = {
                "mode": selModeFor(mods)
            };
            mode = "lasso";
            break;
        case "wand":
            PaintDoc.send({
                "op": "sel",
                "kind": "wand",
                "layer": PaintDoc.activeId,
                "x": x,
                "y": y,
                "tol": PaintDoc.tolerance,
                "global": PaintDoc.globalFill,
                "mode": selModeFor(mods)
            });
            break;
        case "moveSelected":
            {
                const a = PaintDoc.active;
                if (!a)
                    return;
                start = {
                    "x": x,
                    "y": y,
                    "ox": a.x,
                    "oy": a.y
                };
                if (a.kind === "text") {
                    mode = "textmove";
                } else {
                    PaintDoc.send({
                        "op": "move",
                        "phase": "begin",
                        "layer": a.id
                    });
                    mode = "move";
                }
            }
            break;
        case "moveSel":
            start = {
                "x": x,
                "y": y
            };
            PaintDoc.send({
                "op": "sel",
                "kind": "move",
                "phase": "begin"
            });
            mode = "movesel";
            break;
        case "zoom":
            view.zoomAt(sx, sy, (button === Qt.RightButton || (mods & Qt.AltModifier)) ? 1 / 1.5 : 1.5);
            break;
        case "bucket":
            {
                const a = activeRaster();
                if (a)
                    PaintDoc.send({
                        "op": "fill",
                        "layer": a.id,
                        "x": x,
                        "y": y,
                        "tol": PaintDoc.tolerance,
                        "global": PaintDoc.globalFill,
                        "color": colors(button)[0]
                    });
            }
            break;
        case "gradient":
            if (activeRaster()) {
                gradLine = {
                    "x0": x,
                    "y0": y,
                    "x1": x,
                    "y1": y,
                    "button": button
                };
                mode = "gradient";
            }
            break;
        case "picker":
            pickTarget = button === Qt.RightButton ? 1 : 0;
            PaintDoc.send({
                "op": "pick",
                "x": x,
                "y": y,
                "layer": PaintDoc.activeId,
                "source": PaintDoc.pickSource
            });
            break;
        case "text":
            textPress(x, y);
            break;
        case "line":
        case "shape":
            shapePress(x, y, mods);
            break;
        default:
            strokePress(x, y, button, mods);
        }
        changed();
    }

    function strokePress(x, y, button, mods) {
        if (tool === "clone" && (mods & (Qt.AltModifier | Qt.ControlModifier))) {
            cloneSrc = {
                "x": x,
                "y": y
            };
            cloneOffset = null;
            PaintDoc.say("Clone source set: now paint to copy from it");
            return;
        }
        if (tool === "clone" && !cloneSrc) {
            PaintDoc.say("Hold Ctrl and click to choose where to clone from");
            return;
        }
        const a = activeRaster();
        if (!a)
            return;
        if (tool === "clone" && !cloneOffset)
            cloneOffset = {
                "x": cloneSrc.x - x,
                "y": cloneSrc.y - y
            };
        const c = colors(button);
        PaintDoc.send({
            "op": "stroke",
            "phase": "begin",
            "kind": tool,
            "layer": a.id,
            "x": x,
            "y": y,
            "size": PaintDoc.brushSize,
            "hardness": PaintDoc.hardness,
            "spacing": PaintDoc.spacing,
            "color": c[0],
            "color2": c[1],
            "aa": PaintDoc.antialias,
            "tol": PaintDoc.tolerance,
            "ox": cloneOffset ? cloneOffset.x : 0,
            "oy": cloneOffset ? cloneOffset.y : 0
        });
        mode = "stroke";
    }

    function move(x, y, buttons, mods, sx, sy) {
        cursor = Qt.point(x, y);
        switch (mode) {
        case "pan":
            view.panBy(sx - lastSx, sy - lastSy);
            lastSx = sx;
            lastSy = sy;
            return;
        case "stroke":
            PaintDoc.send({
                "op": "stroke",
                "phase": "move",
                "x": x,
                "y": y
            });
            break;
        case "rubber":
            {
                let nx = x, ny = y;
                if (mods & Qt.ShiftModifier)
                    [nx, ny] = constrain(rubber.x0, rubber.y0, x, y);
                rubber = Object.assign({}, rubber, {
                    "x1": nx,
                    "y1": ny
                });
            }
            break;
        case "lasso":
            {
                const l = lasso[lasso.length - 1];
                if (Math.hypot(x - l[0], y - l[1]) >= 1) {
                    lasso.push([x, y]);
                    lasso = lasso;
                }
            }
            break;
        case "move":
            PaintDoc.send({
                "op": "move",
                "phase": "move",
                "dx": x - start.x,
                "dy": y - start.y
            });
            break;
        case "movesel":
            PaintDoc.send({
                "op": "sel",
                "kind": "move",
                "phase": "move",
                "dx": x - start.x,
                "dy": y - start.y
            });
            break;
        case "textmove":
            PaintDoc.send({
                "op": "text.pos",
                "layer": PaintDoc.activeId,
                "x0": start.ox + x - start.x,
                "y0": start.oy + y - start.y
            });
            break;
        case "gradient":
            gradLine = Object.assign({}, gradLine, {
                "x1": x,
                "y1": y
            });
            break;
        case "handle":
            dragHandle(x, y, mods);
            break;
        case "pmove":
            {
                const dx = x - start.x, dy = y - start.y;
                const p = start.p;
                pending = Object.assign({}, pending, {
                    "x0": p.x0 + dx,
                    "y0": p.y0 + dy,
                    "x1": p.x1 + dx,
                    "y1": p.y1 + dy
                });
            }
            break;
        }
        changed();
    }

    function release(x, y, button, mods) {
        const m = mode;
        mode = "";
        switch (m) {
        case "stroke":
            PaintDoc.send({
                "op": "stroke",
                "phase": "end",
                "label": ({
                        "brush": "Paintbrush",
                        "eraser": "Eraser",
                        "pencil": "Pencil",
                        "clone": "Clone stamp",
                        "recolor": "Recolor"
                    })[tool],
                "icon": ({
                        "brush": "brush",
                        "eraser": "ink_eraser",
                        "pencil": "edit",
                        "clone": "content_copy",
                        "recolor": "palette"
                    })[tool]
            });
            break;
        case "rubber":
            {
                const r = rubber;
                rubber = null;
                if (Math.abs(r.x1 - r.x0) < 2 && Math.abs(r.y1 - r.y0) < 2) {
                    PaintDoc.send({
                        "op": "sel",
                        "kind": "none"
                    });
                } else {
                    PaintDoc.send({
                        "op": "sel",
                        "kind": r.ellipse ? "ellipse" : "rect",
                        "x0": r.x0,
                        "y0": r.y0,
                        "x1": r.x1,
                        "y1": r.y1,
                        "mode": r.mode
                    });
                }
            }
            break;
        case "lasso":
            {
                const pts = lasso;
                lasso = [];
                PaintDoc.send(pts.length < 3 ? {
                    "op": "sel",
                    "kind": "none"
                } : {
                    "op": "sel",
                    "kind": "lasso",
                    "pts": pts,
                    "mode": start.mode
                });
            }
            break;
        case "move":
            PaintDoc.send({
                "op": "move",
                "phase": "end"
            });
            break;
        case "movesel":
            PaintDoc.send({
                "op": "sel",
                "kind": "move",
                "phase": "end"
            });
            break;
        case "textmove":
            PaintDoc.send({
                "op": "text.pos",
                "layer": PaintDoc.activeId,
                "x0": start.ox + x - start.x,
                "y0": start.oy + y - start.y,
                "final": true
            });
            break;
        case "gradient":
            {
                const g = gradLine;
                gradLine = null;
                const c = colors(g.button);
                if (Math.hypot(g.x1 - g.x0, g.y1 - g.y0) >= 2)
                    PaintDoc.send({
                        "op": "gradient",
                        "layer": PaintDoc.activeId,
                        "mode": PaintDoc.gradientMode,
                        "x0": g.x0,
                        "y0": g.y0,
                        "x1": g.x1,
                        "y1": g.y1,
                        "color": c[0],
                        "color2": c[1]
                    });
            }
            break;
        case "handle":
        case "pmove":
            if (pending && Math.hypot(pending.x1 - pending.x0, pending.y1 - pending.y0) < 2 && !pending.bentOnce)
                pending = null;
            break;
        }
        changed();
    }

    function hover(x, y) {
        cursor = Qt.point(x, y);
        changed();
    }

    // ---- line / shape that stays editable until it is committed ----

    function handles() {
        const p = pending;
        if (!p)
            return [];
        if (p.kind === "line")
            return [[p.x0, p.y0], [p.x1, p.y1], [p.c1x, p.c1y], [p.c2x, p.c2y]];
        return [[p.x0, p.y0], [p.x1, p.y1]];
    }

    function thirds(p) {
        return {
            "c1x": p.x0 + (p.x1 - p.x0) / 3,
            "c1y": p.y0 + (p.y1 - p.y0) / 3,
            "c2x": p.x0 + (p.x1 - p.x0) * 2 / 3,
            "c2y": p.y0 + (p.y1 - p.y0) * 2 / 3
        };
    }

    function shapePress(x, y, mods) {
        if (!activeRaster())
            return;
        const reach = 10 / view.zoom;
        if (pending && pending.kind === (tool === "line" ? "line" : "shape")) {
            const h = handles();
            for (let i = 0; i < h.length; i++) {
                if (Math.hypot(h[i][0] - x, h[i][1] - y) <= reach) {
                    handleIdx = i;
                    mode = "handle";
                    return;
                }
            }
            if (tool === "shape" && x >= Math.min(pending.x0, pending.x1) && x <= Math.max(pending.x0, pending.x1) && y >= Math.min(pending.y0, pending.y1) && y <= Math.max(pending.y0, pending.y1)) {
                start = {
                    "x": x,
                    "y": y,
                    "p": pending
                };
                mode = "pmove";
                return;
            }
        }
        commitPending();
        const p = {
            "kind": tool === "line" ? "line" : "shape",
            "x0": x,
            "y0": y,
            "x1": x,
            "y1": y
        };
        pending = Object.assign(p, thirds(p));
        bent = false;
        handleIdx = 1;
        mode = "handle";
    }

    function dragHandle(x, y, mods) {
        const p = Object.assign({}, pending);
        const keys = [["x0", "y0"], ["x1", "y1"], ["c1x", "c1y"], ["c2x", "c2y"]][handleIdx];
        let nx = x, ny = y;
        if ((mods & Qt.ShiftModifier) && handleIdx < 2) {
            const ox = handleIdx === 1 ? p.x0 : p.x1, oy = handleIdx === 1 ? p.y0 : p.y1;
            [nx, ny] = p.kind === "line" ? snapAngle(ox, oy, x, y) : constrain(ox, oy, x, y);
        }
        p[keys[0]] = nx;
        p[keys[1]] = ny;
        if (handleIdx >= 2)
            p.bentOnce = true;
        else if (!p.bentOnce)
            Object.assign(p, thirds(p));
        pending = p;
    }

    function commitPending() {
        const p = pending;
        pending = null;
        if (!p || (Math.hypot(p.x1 - p.x0, p.y1 - p.y0) < 2 && !p.bentOnce))
            return;
        const a = PaintDoc.active;
        if (!a || a.kind !== "raster")
            return;
        const isLine = p.kind === "line";
        PaintDoc.send({
            "op": "shape",
            "kind": isLine ? (p.bentOnce ? "curve" : "line") : PaintDoc.shapeKind,
            "layer": a.id,
            "x0": p.x0,
            "y0": p.y0,
            "x1": p.x1,
            "y1": p.y1,
            "cx": p.c1x,
            "cy": p.c1y,
            "c2x": p.c2x,
            "c2y": p.c2y,
            "width": PaintDoc.lineWidth,
            "radius": PaintDoc.cornerRadius,
            "fill": isLine ? "outline" : PaintDoc.shapeFill,
            "color": PaintDoc.hex8(PaintDoc.primary),
            "color2": PaintDoc.hex8(PaintDoc.secondary),
            "aa": PaintDoc.antialias,
            "label": isLine ? (p.bentOnce ? "Curve" : "Line") : "Shape",
            "icon": isLine ? "timeline" : "interests"
        });
        changed();
    }

    function cancelPending() {
        pending = null;
        changed();
    }

    // ---- text ----

    function textPress(x, y) {
        if (editId > 0)
            commitText();
        const ls = PaintDoc.layers;
        for (let i = ls.length - 1; i >= 0; i--) {
            const l = ls[i];
            if (l.kind === "text" && l.visible && x >= l.x && y >= l.y && x <= l.x + l.tw && y <= l.y + l.th) {
                PaintDoc.select(l.id);
                startEdit(l);
                return;
            }
        }
        PaintDoc.pendingTextEdit = true;
        PaintDoc.send({
            "op": "text.new",
            "x0": x,
            "y0": y,
            "props": PaintDoc.textProps("")
        });
    }

    function startEdit(l) {
        const p = l.props || ({});
        PaintDoc.textFamily = p.family ?? PaintDoc.textFamily;
        PaintDoc.textSize = p.size ?? PaintDoc.textSize;
        PaintDoc.textBold = p.bold ?? false;
        PaintDoc.textItalic = p.italic ?? false;
        PaintDoc.textUnderline = p.underline ?? false;
        PaintDoc.textAlign = p.align ?? "left";
        if (p.color)
            PaintDoc.primary = p.color;
        editId = l.id;
        editIsNew = false;
        editText = p.text ?? "";
        editX = l.x;
        editY = l.y;
        PaintDoc.send({
            "op": "editing",
            "layer": l.id
        });
        changed();
    }

    function commitText() {
        const id = editId;
        if (id <= 0)
            return;
        const text = editText, isNew = editIsNew;
        editId = 0;
        const l = PaintDoc.layers.find(x => x.id === id);
        if (text.trim() === "") {
            PaintDoc.send(isNew ? {
                "op": "text.discard",
                "layer": id
            } : {
                "op": "layer",
                "kind": "delete",
                "layer": id
            });
        } else if (!isNew && l && l.props && l.props.text === text && sameProps(l.props)) {
            PaintDoc.send({
                "op": "editing",
                "layer": 0
            });
        } else {
            renderText(id, PaintDoc.textProps(text), editX, editY, text.split("\n")[0].slice(0, 24));
        }
        changed();
    }

    function cancelText() {
        const id = editId;
        if (id <= 0)
            return;
        editId = 0;
        PaintDoc.send(editIsNew ? {
            "op": "text.discard",
            "layer": id
        } : {
            "op": "editing",
            "layer": 0
        });
        changed();
    }

    function sameProps(p) {
        return p.family === PaintDoc.textFamily && p.size === PaintDoc.textSize && !!p.bold === PaintDoc.textBold && !!p.italic === PaintDoc.textItalic && !!p.underline === PaintDoc.textUnderline && p.align === PaintDoc.textAlign && p.color === String(PaintDoc.primary);
    }

    function finishEdits() {
        commitPending();
        commitText();
        gradLine = null;
        rubber = null;
        changed();
    }

    Connections {
        function onPicked(color) {
            const c = PaintDoc.fromHex8(color);
            if (root.pickTarget === 1)
                PaintDoc.secondary = c;
            else
                PaintDoc.primary = c;
            PaintDoc.addRecent(c);
        }

        function onTextEditRequested(id) {
            const l = PaintDoc.layers.find(x => x.id === id);
            if (!l)
                return;
            root.editId = id;
            root.editIsNew = true;
            root.editText = "";
            root.editX = l.x;
            root.editY = l.y;
            root.changed();
        }

        function onReset() {
            root.pending = null;
            root.editId = 0;
            root.rubber = null;
            root.cloneSrc = null;
            root.cloneOffset = null;
            root.changed();
        }

        target: PaintDoc
    }

    onToolChanged: finishEdits()
}
