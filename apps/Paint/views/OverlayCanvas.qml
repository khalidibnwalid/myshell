import ".."
import "../../../config"
import QtQuick

// Everything drawn over the picture on the screen (not in it): the rubber band, the lasso, the line or
// shape that can still be edited, the gradient line, the brush outline and the clone source.
Canvas {
    id: root

    required property var handler
    required property real zoom
    required property real panX
    required property real panY

    function sx(x) {
        return panX + x * zoom;
    }

    function sy(y) {
        return panY + y * zoom;
    }

    function poly(n, x0, y0, x1, y1, star) {
        const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, rx = Math.abs(x1 - x0) / 2, ry = Math.abs(y1 - y0) / 2, cnt = star ? n * 2 : n, out = [];
        for (let i = 0; i < cnt; i++) {
            const a = -Math.PI / 2 + 2 * Math.PI * i / cnt, k = star && i % 2 === 1 ? 0.42 : 1;
            out.push([cx + Math.cos(a) * rx * k, cy + Math.sin(a) * ry * k]);
        }
        return out;
    }

    function shapePoints(p) {
        const kind = PaintDoc.shapeKind, x0 = p.x0, y0 = p.y0, x1 = p.x1, y1 = p.y1;
        switch (kind) {
        case "ellipse":
            return poly(96, x0, y0, x1, y1, false);
        case "triangle":
            return [[(x0 + x1) / 2, y0], [x1, y1], [x0, y1]];
        case "diamond":
            return poly(4, x0, y0, x1, y1, false);
        case "pentagon":
            return poly(5, x0, y0, x1, y1, false);
        case "hexagon":
            return poly(6, x0, y0, x1, y1, false);
        case "star":
            return poly(5, x0, y0, x1, y1, true);
        case "rrect":
            {
                const lx = Math.min(x0, x1), hx = Math.max(x0, x1), ly = Math.min(y0, y1), hy = Math.max(y0, y1);
                const r = Math.min(PaintDoc.cornerRadius, Math.min(hx - lx, hy - ly) / 2), out = [];
                const corner = (cx, cy, a0) => {
                    for (let i = 0; i <= 8; i++) {
                        const a = a0 + Math.PI / 2 * i / 8;
                        out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
                    }
                };
                corner(hx - r, ly + r, -Math.PI / 2);
                corner(hx - r, hy - r, 0);
                corner(lx + r, hy - r, Math.PI / 2);
                corner(lx + r, ly + r, Math.PI);
                return out;
            }
        }
        return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
    }

    function dashed(ctx) {
        ctx.setLineDash([5, 4]);
    }

    function handle(ctx, x, y) {
        ctx.beginPath();
        ctx.rect(sx(x) - 4, sy(y) - 4, 8, 8);
        ctx.fillStyle = "#ffffff";
        ctx.fill();
        ctx.strokeStyle = "#1a73e8";
        ctx.lineWidth = 1.5;
        ctx.setLineDash([]);
        ctx.stroke();
    }

    anchors.fill: parent
    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Cooperative
    onZoomChanged: requestPaint()
    onPanXChanged: requestPaint()
    onPanYChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const h = handler;
        const accent = "#1a73e8";
        if (h.rubber) {
            const r = h.rubber;
            ctx.lineWidth = 1;
            ctx.strokeStyle = "#ffffff";
            ctx.setLineDash([]);
            ctx.beginPath();
            if (r.ellipse)
                ctx.ellipse(sx(Math.min(r.x0, r.x1)), sy(Math.min(r.y0, r.y1)), Math.abs(r.x1 - r.x0) * zoom, Math.abs(r.y1 - r.y0) * zoom);
            else
                ctx.rect(sx(Math.min(r.x0, r.x1)), sy(Math.min(r.y0, r.y1)), Math.abs(r.x1 - r.x0) * zoom, Math.abs(r.y1 - r.y0) * zoom);
            ctx.stroke();
            ctx.strokeStyle = "#000000";
            dashed(ctx);
            ctx.stroke();
        }
        if (h.lasso.length > 1) {
            ctx.beginPath();
            ctx.moveTo(sx(h.lasso[0][0]), sy(h.lasso[0][1]));
            for (let i = 1; i < h.lasso.length; i++)
                ctx.lineTo(sx(h.lasso[i][0]), sy(h.lasso[i][1]));
            ctx.lineWidth = 1;
            ctx.strokeStyle = "#ffffff";
            ctx.setLineDash([]);
            ctx.stroke();
            ctx.strokeStyle = "#000000";
            dashed(ctx);
            ctx.stroke();
        }
        if (h.gradLine) {
            const g = h.gradLine;
            ctx.setLineDash([]);
            ctx.lineWidth = 2;
            ctx.strokeStyle = "#ffffff";
            ctx.beginPath();
            ctx.moveTo(sx(g.x0), sy(g.y0));
            ctx.lineTo(sx(g.x1), sy(g.y1));
            ctx.stroke();
            ctx.lineWidth = 1;
            ctx.strokeStyle = "#000000";
            ctx.stroke();
            handle(ctx, g.x0, g.y0);
            handle(ctx, g.x1, g.y1);
        }
        const p = h.pending;
        if (p) {
            ctx.setLineDash([]);
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.lineWidth = Math.max(1, PaintDoc.lineWidth * zoom);
            ctx.strokeStyle = String(PaintDoc.primary);
            ctx.fillStyle = String(PaintDoc.shapeFill === "both" ? PaintDoc.secondary : PaintDoc.primary);
            ctx.beginPath();
            if (p.kind === "line") {
                ctx.moveTo(sx(p.x0), sy(p.y0));
                ctx.bezierCurveTo(sx(p.c1x), sy(p.c1y), sx(p.c2x), sy(p.c2y), sx(p.x1), sy(p.y1));
                ctx.stroke();
                ctx.lineWidth = 1;
                ctx.strokeStyle = Qt.alpha(accent, 0.6);
                ctx.beginPath();
                ctx.moveTo(sx(p.x0), sy(p.y0));
                ctx.lineTo(sx(p.c1x), sy(p.c1y));
                ctx.moveTo(sx(p.x1), sy(p.y1));
                ctx.lineTo(sx(p.c2x), sy(p.c2y));
                ctx.stroke();
            } else {
                const pts = shapePoints(p);
                ctx.moveTo(sx(pts[0][0]), sy(pts[0][1]));
                for (let i = 1; i < pts.length; i++)
                    ctx.lineTo(sx(pts[i][0]), sy(pts[i][1]));
                ctx.closePath();
                if (PaintDoc.shapeFill !== "outline")
                    ctx.fill();
                if (PaintDoc.shapeFill !== "fill")
                    ctx.stroke();
            }
            for (const q of h.handles())
                handle(ctx, q[0], q[1]);
        }
        if (h.cloneSrc && PaintDoc.tool === "clone") {
            const x = sx(h.cloneSrc.x), y = sy(h.cloneSrc.y);
            ctx.setLineDash([]);
            ctx.lineWidth = 2;
            ctx.strokeStyle = "#ffffff";
            ctx.beginPath();
            ctx.moveTo(x - 8, y);
            ctx.lineTo(x + 8, y);
            ctx.moveTo(x, y - 8);
            ctx.lineTo(x, y + 8);
            ctx.stroke();
            ctx.lineWidth = 1;
            ctx.strokeStyle = "#000000";
            ctx.stroke();
        }
        if (h.cursor.x >= 0 && h.drawTools.indexOf(PaintDoc.tool) >= 0 && h.mode !== "pan") {
            const r = Math.max(1, PaintDoc.brushSize * zoom / 2);
            ctx.setLineDash([]);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.arc(sx(h.cursor.x), sy(h.cursor.y), r, 0, Math.PI * 2);
            ctx.strokeStyle = "#ffffff";
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(sx(h.cursor.x), sy(h.cursor.y), r + 1, 0, Math.PI * 2);
            ctx.strokeStyle = "#000000";
            ctx.stroke();
        }
    }

    Connections {
        function onChanged() {
            root.requestPaint();
        }

        target: root.handler
    }

    Connections {
        function onPrimaryChanged() {
            root.requestPaint();
        }

        function onShapeKindChanged() {
            root.requestPaint();
        }

        function onShapeFillChanged() {
            root.requestPaint();
        }

        function onLineWidthChanged() {
            root.requestPaint();
        }

        function onBrushSizeChanged() {
            root.requestPaint();
        }

        function onCornerRadiusChanged() {
            root.requestPaint();
        }

        target: PaintDoc
    }
}
