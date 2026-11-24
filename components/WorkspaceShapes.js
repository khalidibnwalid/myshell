.pragma library

// The shapes a workspace can have in the bar. Each one is a closed outline of points inside the
// unit circle (centre 0,0, radius 1), built by a function, so one renderer draws all of them.

function polygon(n, rot) {
    const p = [];
    for (let i = 0; i < n; i++) {
        const a = rot + i * 2 * Math.PI / n;
        p.push([Math.cos(a), Math.sin(a)]);
    }
    return p;
}

function star(n, inner) {
    const p = [];
    for (let i = 0; i < n * 2; i++) {
        const a = -Math.PI / 2 + i * Math.PI / n;
        const r = i % 2 === 0 ? 1 : inner;
        p.push([r * Math.cos(a), r * Math.sin(a)]);
    }
    return p;
}

// a circle whose radius swells and shrinks n times (flowers, scalloped discs)
function wave(n, depth) {
    const p = [];
    for (let i = 0; i < 96; i++) {
        const a = i * 2 * Math.PI / 96;
        const r = (1 - depth) + depth * (0.5 + 0.5 * Math.cos(n * a));
        p.push([r * Math.cos(a - Math.PI / 2), r * Math.sin(a - Math.PI / 2)]);
    }
    return p;
}

function heart() {
    const p = [];
    for (let i = 0; i < 64; i++) {
        const t = i * 2 * Math.PI / 64;
        p.push([16 * Math.pow(Math.sin(t), 3) / 17, -(13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t) + 2) / 17]);
    }
    return p;
}

// Round every corner of a closed outline: each corner is cut `r` back along both edges (or half
// the edge if it is shorter) and replaced by a small curve, so tips are soft instead of sharp.
function round(pts, r) {
    const out = [];
    const n = pts.length;
    for (let i = 0; i < n; i++) {
        const a = pts[(i + n - 1) % n], b = pts[i], c = pts[(i + 1) % n];
        const la = Math.hypot(a[0] - b[0], a[1] - b[1]);
        const lc = Math.hypot(c[0] - b[0], c[1] - b[1]);
        const k = Math.min(r, la / 2, lc / 2);
        const p0 = [b[0] + (a[0] - b[0]) * k / la, b[1] + (a[1] - b[1]) * k / la];
        const p1 = [b[0] + (c[0] - b[0]) * k / lc, b[1] + (c[1] - b[1]) * k / lc];
        for (let t = 0; t <= 6; t++) {
            const u = t / 6, v = 1 - u;
            out.push([v * v * p0[0] + 2 * u * v * b[0] + u * u * p1[0], v * v * p0[1] + 2 * u * v * b[1] + u * u * p1[1]]);
        }
    }
    return out;
}

function circle() {
    return polygon(40, 0);
}

function squircle() {
    const p = [];
    for (let i = 0; i < 64; i++) {
        const t = i * 2 * Math.PI / 64;
        const c = Math.cos(t), s = Math.sin(t);
        p.push([Math.sign(c) * Math.pow(Math.abs(c), 0.5), Math.sign(s) * Math.pow(Math.abs(s), 0.5)]);
    }
    return p;
}

function plus(w) {
    return [[-w, -1], [w, -1], [w, -w], [1, -w], [1, w], [w, w], [w, 1], [-w, 1], [-w, w], [-1, w], [-1, -w], [-w, -w]];
}

function arrow() {
    return [[0, -1], [1, 0], [0.4, 0], [0.4, 1], [-0.4, 1], [-0.4, 0], [-1, 0]];
}

function bolt() {
    return [[0.25, -1], [-0.7, 0.15], [-0.05, 0.15], [-0.3, 1], [0.7, -0.2], [0.05, -0.2]];
}

function moon() {
    const p = [];
    // outer circle arc, then the inner arc back
    for (let i = 0; i <= 24; i++) {
        const a = -Math.PI * 0.62 + i * Math.PI * 1.24 / 24 + Math.PI;
        p.push([Math.cos(a), Math.sin(a)]);
    }
    for (let i = 24; i >= 0; i--) {
        const a = -Math.PI * 0.62 + i * Math.PI * 1.24 / 24 + Math.PI;
        p.push([0.35 + 0.78 * Math.cos(a), 0.78 * Math.sin(a)]);
    }
    return p;
}

// id, name, builder; the first one is the default and is drawn as a round dot
const list = [
    { "id": "dot", "name": "Dot", "build": circle },
    { "id": "square", "name": "Square", "build": () => round(polygon(4, Math.PI / 4).map(q => [q[0] * 0.9, q[1] * 0.9]), 0.3) },
    { "id": "squircle", "name": "Soft square", "build": squircle },
    { "id": "diamond", "name": "Diamond", "build": () => round(polygon(4, 0), 0.25) },
    { "id": "triangle", "name": "Triangle", "build": () => round(polygon(3, -Math.PI / 2), 0.3) },
    { "id": "triangleDown", "name": "Triangle down", "build": () => round(polygon(3, Math.PI / 2), 0.3) },
    { "id": "pentagon", "name": "Pentagon", "build": () => round(polygon(5, -Math.PI / 2), 0.25) },
    { "id": "hexagon", "name": "Hexagon", "build": () => round(polygon(6, 0), 0.22) },
    { "id": "octagon", "name": "Octagon", "build": () => round(polygon(8, Math.PI / 8), 0.18) },
    { "id": "star4", "name": "4-point star", "build": () => round(star(4, 0.4), 0.2) },
    { "id": "star5", "name": "5-point star", "build": () => round(star(5, 0.45), 0.2) },
    { "id": "star6", "name": "6-point star", "build": () => round(star(6, 0.55), 0.18) },
    { "id": "star8", "name": "8-point star", "build": () => round(star(8, 0.62), 0.15) },
    { "id": "burst", "name": "Burst", "build": () => round(star(12, 0.75), 0.12) },
    { "id": "plus", "name": "Plus", "build": () => round(plus(0.36), 0.18) },
    { "id": "heart", "name": "Heart", "build": heart },
    { "id": "flower", "name": "Flower", "build": () => wave(5, 0.35) },
    { "id": "clover", "name": "Clover", "build": () => wave(4, 0.5) },
    { "id": "scallop", "name": "Scalloped", "build": () => wave(10, 0.14) },
    { "id": "arrow", "name": "Arrow", "build": () => round(arrow(), 0.15) },
    { "id": "bolt", "name": "Bolt", "build": () => round(bolt(), 0.1) },
    { "id": "moon", "name": "Moon", "build": moon }
]

const defaultId = "dot"

function find(id) {
    for (let i = 0; i < list.length; i++)
        if (list[i].id === id)
            return list[i];
    return list[0];
}

// points of a shape in a box of `size` pixels, as [{x, y}] for a PathPolyline
function points(id, size) {
    const half = size / 2;
    return find(id).build().map(q => Qt.point(half + q[0] * half, half + q[1] * half));
}

// the "|"-separated setting: shape id of workspace number n (1-based)
function shapeOf(setting, n) {
    const parts = (setting || "").split("|");
    const id = parts[n - 1];
    return find(id).id;
}

function withShape(setting, n, id) {
    const parts = (setting || "").split("|");
    while (parts.length < n)
        parts.push("");
    parts[n - 1] = id === defaultId ? "" : id;
    while (parts.length > 0 && parts[parts.length - 1] === "")
        parts.pop();
    return parts.join("|");
}
