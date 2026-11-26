import "../../components"
import "../../config/"
import "../../services" as Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The screenshot editor: draw arrows, boxes, lines and text on a shot, pixelate or blur what must not be
// seen, crop it, then copy or save it. Marks are kept in the image's own pixels and the result is
// rendered at the image's size, whatever the window's zoom or the screen's scale.
// Opened by Services.ScreenTools.editImage(path) (the notification's Edit button, `qs ipc call capture edit`).
ApplicationWindow {
    id: root

    readonly property string path: Services.ScreenTools.editorPath
    // image pixels per screen point (Hyprland's scale: Qt rounds a fractional one up), so lines and text
    // are sized like on the screen and the image opens at its real size
    readonly property real unit: Math.max(1, Hyprland.focusedMonitor?.scale ?? content.Screen.devicePixelRatio ?? 1)
    readonly property int imageWidth: photo.implicitWidth
    readonly property int imageHeight: photo.implicitHeight
    // every change is a mark; undo takes the last one off, redo puts it back
    property var marks: []
    property var undone: []
    // the mark being drawn
    property var draft: null
    // the text being typed ({ x, y } in image pixels), null when none
    property var typing: null
    property string status: ""
    // the last crop wins
    readonly property rect crop: {
        for (let i = marks.length - 1; i >= 0; i--) {
            if (marks[i].kind === "crop")
                return Qt.rect(marks[i].x, marks[i].y, marks[i].w, marks[i].h);
        }
        return Qt.rect(0, 0, imageWidth, imageHeight);
    }
    // shown at its real size when it fits, smaller when it does not
    readonly property real zoom: Math.min(1 / unit, (stage.width - 32) / Math.max(1, crop.width), (stage.height - 32) / Math.max(1, crop.height))
    readonly property string tool: Services.ScreenTools.editorTool
    readonly property color penColor: Services.ScreenTools.editorColor
    readonly property int size: Services.ScreenTools.editorSize
    readonly property real lineWidth: [3, 5, 9][size] * unit
    readonly property real markerWidth: [14, 22, 34][size] * unit
    readonly property real textSize: [18, 26, 40][size] * unit
    readonly property real cell: [8, 14, 22][size] * unit
    // the size to ask a grab for, in window points (see render)
    readonly property size grabSize: Qt.size(Math.ceil(crop.width / unit - 1e-6), Math.ceil(crop.height / unit - 1e-6))

    function add(mark) {
        marks = marks.concat([mark]);
        undone = [];
    }

    function undo() {
        finishText();
        if (marks.length === 0)
            return;
        undone = undone.concat([marks[marks.length - 1]]);
        marks = marks.slice(0, -1);
    }

    function redo() {
        finishText();
        if (undone.length === 0)
            return;
        marks = marks.concat([undone[undone.length - 1]]);
        undone = undone.slice(0, -1);
    }

    function chooseTool(id) {
        finishText();
        Services.ScreenTools.editorTool = id;
    }

    function startText(x, y) {
        typing = {
            "x": x,
            "y": y
        };
        input.text = "";
        Qt.callLater(() => input.forceActiveFocus());
    }

    // keeps what was typed as a mark (nothing when it is empty)
    function finishText() {
        if (!typing)
            return;
        const text = input.text;
        const at = typing;
        typing = null;
        if (text.trim() !== "")
            add({
                "kind": "text",
                "x": at.x,
                "y": at.y,
                "text": text,
                "color": penColor.toString(),
                "size": textSize
            });
        input.text = "";
        keys.forceActiveFocus();
    }

    // renders the cropped image with its marks at the image's own size into `file`, then runs `then`.
    // A grab is made at the window's scale, so it is asked for at size / scale; when that cannot give the
    // exact size (1.6 reaches only some widths) it comes out a pixel larger and ffmpeg trims it
    function render(file, then) {
        finishText();
        draft = null;
        const exact = exportBox.width === crop.width && exportBox.height === crop.height;
        const raw = exact ? file : file + ".raw.png";
        exportBox.grabToImage(result => {
            if (!result.saveToFile(raw)) {
                root.say("Could not write the image");
            } else if (exact) {
                then();
            } else {
                trimProc.then = then;
                trimProc.command = ["sh", "-c", "ffmpeg -v error -y -i \"$1\" -vf \"crop=$3:$4:0:0\" \"$2\"; s=$?; rm -f \"$1\"; exit $s", "sh", raw, file, String(crop.width), String(crop.height)];
                trimProc.running = true;
            }
        }, grabSize);
    }

    function copy() {
        const file = Services.ScreenTools.cacheDir + "/edited-" + Date.now() + ".png";
        render(file, () => {
            Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\"; rm -f \"$1\"", "sh", file]);
            root.say("Copied to the clipboard");
        });
    }

    function save() {
        const file = Services.ScreenTools.cacheDir + "/edited-" + Date.now() + ".png";
        const dir = Services.ScreenTools.expand(Config.capture.screenshotDir);
        const name = dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
        render(file, () => {
            saveProc.command = ["sh", "-c", "mkdir -p \"$1\" || exit 1; n=\"$3\"; i=1; while [ -e \"$n\" ]; do n=\"${3%.png}-$i.png\"; i=$((i + 1)); done; mv \"$2\" \"$n\" && printf %s \"$n\"", "sh", dir, file, name];
            saveProc.running = true;
        });
    }

    function say(text) {
        status = text;
        statusTimer.restart();
    }

    function closeEditor() {
        Services.ScreenTools.closeEditor();
    }

    // the window opens at the image's real size, within most of the screen
    width: Math.round(Math.max(760, Math.min((screen ? screen.width : 1920) * 0.85, imageWidth / unit + 64)))
    height: Math.round(Math.max(520, Math.min((screen ? screen.height : 1080) * 0.85, imageHeight / unit + 190)))
    minimumWidth: 760
    minimumHeight: 520
    title: "Screenshot editor"
    visible: true
    color: Qt.alpha(Appearance.bgColor, Appearance.isLight ? 1 - Math.pow(1 - Config.appearance.settingsOpacity, 2) : Config.appearance.settingsOpacity)
    onClosing: closeEditor()
    onPathChanged: {
        marks = [];
        undone = [];
        draft = null;
        typing = null;
    }
    Component.onCompleted: {
        // the rendered images pass through the cache folder, which an image opened over IPC may not have made
        Quickshell.execDetached(["mkdir", "-p", Services.ScreenTools.cacheDir]);
        keys.forceActiveFocus();
    }
    // gone some other way than closeEditor: the next Edit must open a new window
    Component.onDestruction: {
        if (Services.ScreenTools.editorPath === path)
            Services.ScreenTools.editorPath = "";
    }

    Timer {
        id: statusTimer

        interval: 3500
        onTriggered: root.status = ""
    }

    Process {
        id: trimProc

        property var then: null

        onExited: code => {
            if (code === 0 && then)
                then();
            else if (code !== 0)
                root.say("Could not write the image (ffmpeg)");
            then = null;
        }
    }

    Process {
        id: saveProc

        stdout: StdioCollector {
            onStreamFinished: root.say(this.text !== "" ? "Saved as " + this.text.replace(Services.ScreenTools.home, "~") : "Could not save the screenshot")
        }
    }

    // takes the keys no control used. Letters choose tools only here, so they never reach a text being typed
    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            const shift = event.modifiers & Qt.ShiftModifier;
            if (event.key === Qt.Key_Escape) {
                if (root.typing)
                    root.finishText();
                else if (root.draft)
                    root.draft = null;
                else
                    root.closeEditor();
            } else if (ctrl && event.key === Qt.Key_Z && !shift)
                root.undo();
            else if (ctrl && (event.key === Qt.Key_Y || event.key === Qt.Key_Z))
                root.redo();
            else if (ctrl && event.key === Qt.Key_C)
                root.copy();
            else if (ctrl && event.key === Qt.Key_S)
                root.save();
            else if (ctrl && event.key === Qt.Key_W)
                root.closeEditor();
            else if (!ctrl && !(event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_3)
                Services.ScreenTools.editorSize = event.key - Qt.Key_1;
            else if (!ctrl && !(event.modifiers & Qt.AltModifier) && toolKeys[event.key] !== undefined)
                root.chooseTool(toolKeys[event.key]);
            else
                return;
            event.accepted = true;
        }

        readonly property var toolKeys: ({
                [Qt.Key_A]: "arrow",
                [Qt.Key_R]: "rect",
                [Qt.Key_P]: "pen",
                [Qt.Key_H]: "marker",
                [Qt.Key_T]: "text",
                [Qt.Key_X]: "pixelate",
                [Qt.Key_B]: "blur",
                [Qt.Key_C]: "crop"
            })

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // title, size and the actions
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 6

                MaterialSymbol {
                    icon: "screenshot_region"
                    font.pixelSize: 22
                    color: Appearance.accentColor
                }

                StyledText {
                    Layout.leftMargin: 4
                    text: "Screenshot"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    text: root.status !== "" ? root.status : Math.round(root.crop.width) + " × " + Math.round(root.crop.height) + "  ·  Ctrl+C copy, Ctrl+S save, Esc close"
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                IconButton {
                    icon: "undo"
                    opacity: root.marks.length > 0 ? 1 : 0.4
                    onClicked: root.undo()
                    Accessible.name: "Undo (Ctrl+Z)"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Undo  (Ctrl+Z)"
                }

                IconButton {
                    icon: "redo"
                    opacity: root.undone.length > 0 ? 1 : 0.4
                    onClicked: root.redo()
                    Accessible.name: "Redo (Ctrl+Y)"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "Redo  (Ctrl+Y)"
                }

                PillButton {
                    Layout.leftMargin: 6
                    icon: "content_copy"
                    text: "Copy"
                    onClicked: root.copy()
                    Accessible.name: "Copy (Ctrl+C)"
                }

                PillButton {
                    icon: "save"
                    text: "Save"
                    toggled: true
                    onClicked: root.save()
                    Accessible.name: "Save (Ctrl+S)"
                }

                IconButton {
                    Layout.leftMargin: 4
                    icon: "close"
                    onClicked: root.closeEditor()
                    Accessible.name: "Close (Esc)"
                }
            }

            // the image, centred on a tile
            Rectangle {
                id: stage

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 20
                color: Appearance.surfaceColor
                clip: true

                Item {
                    id: scaler

                    width: root.crop.width
                    height: root.crop.height
                    x: (stage.width - width * root.zoom) / 2
                    y: (stage.height - height * root.zoom) / 2
                    scale: root.zoom
                    transformOrigin: Item.TopLeft

                    // what is exported: the cropped part of the sheet, in a box of the size the grab gives
                    // (the same, or a pixel more that is trimmed afterwards)
                    Item {
                        id: exportBox

                        width: Math.round(root.grabSize.width * root.unit)
                        height: Math.round(root.grabSize.height * root.unit)

                        Item {
                            id: frame

                            width: root.crop.width
                            height: root.crop.height
                            clip: true

                            // the whole image and its marks, in image pixels
                            Item {
                                id: sheet

                                x: -root.crop.x
                                y: -root.crop.y
                                width: root.imageWidth
                                height: root.imageHeight

                                Image {
                                    id: photo

                                    source: root.path !== "" ? "file://" + root.path : ""
                                    asynchronous: false
                                    cache: false
                                    smooth: true
                                    mipmap: true
                                }

                                Repeater {
                                    model: root.marks

                                    ShotMark {
                                        required property var modelData

                                        mark: modelData
                                        source: photo
                                    }
                                }

                                ShotMark {
                                    mark: root.draft && root.draft.kind !== "crop" ? root.draft : null
                                    source: photo
                                }

                                TextInput {
                                    id: input

                                    visible: root.typing !== null
                                    x: root.typing ? root.typing.x : 0
                                    y: root.typing ? root.typing.y : 0
                                    color: root.penColor
                                    font.family: Appearance.fontFamily
                                    font.pixelSize: root.textSize
                                    font.weight: Font.Bold
                                    cursorDelegate: Rectangle {
                                        width: Math.max(2, root.unit * 1.5)
                                        color: root.penColor
                                        visible: input.cursorVisible
                                    }
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
                                            root.finishText();
                                            event.accepted = true;
                                        }
                                    }
                                }

                                MouseArea {
                                    id: drawArea

                                    // keeps a point on the image
                                    function at(mouse) {
                                        return Qt.point(Math.max(0, Math.min(root.imageWidth, Math.round(mouse.x))), Math.max(0, Math.min(root.imageHeight, Math.round(mouse.y))));
                                    }

                                    anchors.fill: parent
                                    cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                                    onPressed: mouse => {
                                        root.finishText();
                                        const p = at(mouse);
                                        if (root.tool === "text") {
                                            root.startText(p.x, p.y - root.textSize * 0.6);
                                            return;
                                        }
                                        if (root.tool === "pen" || root.tool === "marker")
                                            root.draft = {
                                                "kind": root.tool,
                                                "color": root.penColor.toString(),
                                                "width": root.tool === "marker" ? root.markerWidth : root.lineWidth,
                                                "points": [{
                                                        "x": p.x,
                                                        "y": p.y
                                                    }]
                                            };
                                        else
                                            root.draft = {
                                                "kind": root.tool,
                                                "color": root.penColor.toString(),
                                                "width": root.lineWidth,
                                                "cell": root.cell,
                                                "x1": p.x,
                                                "y1": p.y,
                                                "x2": p.x,
                                                "y2": p.y
                                            };
                                    }
                                    onPositionChanged: mouse => {
                                        const d = root.draft;
                                        if (!d)
                                            return;
                                        let p = at(mouse);
                                        if (d.points) {
                                            const last = d.points[d.points.length - 1];
                                            if (Math.abs(last.x - p.x) + Math.abs(last.y - p.y) < 2)
                                                return;
                                            root.draft = Object.assign({}, d, {
                                                "points": d.points.concat([{
                                                        "x": p.x,
                                                        "y": p.y
                                                    }])
                                            });
                                            return;
                                        }
                                        // Shift: arrows snap to 45°, boxes are square
                                        if (mouse.modifiers & Qt.ShiftModifier) {
                                            const dx = p.x - d.x1, dy = p.y - d.y1;
                                            if (d.kind === "arrow") {
                                                const a = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * Math.PI / 4;
                                                const l = Math.sqrt(dx * dx + dy * dy);
                                                p = Qt.point(d.x1 + Math.cos(a) * l, d.y1 + Math.sin(a) * l);
                                            } else {
                                                const s = Math.max(Math.abs(dx), Math.abs(dy));
                                                p = Qt.point(d.x1 + (dx < 0 ? -s : s), d.y1 + (dy < 0 ? -s : s));
                                            }
                                        }
                                        root.draft = Object.assign({}, d, {
                                            "x2": p.x,
                                            "y2": p.y
                                        });
                                    }
                                    onReleased: {
                                        const d = root.draft;
                                        root.draft = null;
                                        if (!d)
                                            return;
                                        if (d.points) {
                                            root.add(d);
                                            return;
                                        }
                                        const w = Math.abs(d.x2 - d.x1), h = Math.abs(d.y2 - d.y1);
                                        if (d.kind === "arrow" ? w + h < 6 : (w < 4 || h < 4))
                                            return;
                                        if (d.kind === "crop")
                                            root.add({
                                                "kind": "crop",
                                                "x": Math.min(d.x1, d.x2),
                                                "y": Math.min(d.y1, d.y2),
                                                "w": w,
                                                "h": h
                                            });
                                        else
                                            root.add(d);
                                    }
                                }
                            }
                        }
                    }

                    // the area a crop will keep, while it is being dragged (not part of the image)
                    Rectangle {
                        readonly property var d: root.draft && root.draft.kind === "crop" ? root.draft : null

                        visible: d !== null
                        x: d ? Math.min(d.x1, d.x2) - root.crop.x : 0
                        y: d ? Math.min(d.y1, d.y2) - root.crop.y : 0
                        width: d ? Math.abs(d.x2 - d.x1) : 0
                        height: d ? Math.abs(d.y2 - d.y1) : 0
                        color: Qt.alpha(Appearance.accentColor, 0.12)
                        border.width: 2 / root.zoom
                        border.color: Appearance.accentColor
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: photo.status === Image.Error
                    text: "This image could not be opened"
                    color: Appearance.mutedColor
                }
            }

            ShotToolbar {
                Layout.alignment: Qt.AlignHCenter
                tool: root.tool
                penColor: root.penColor
                size: root.size
                onToolChosen: id => root.chooseTool(id)
                onColorChosen: value => {
                    Services.ScreenTools.editorColor = value;
                    if (root.typing)
                        input.forceActiveFocus();
                }
                onSizeChosen: value => Services.ScreenTools.editorSize = value
            }
        }

        ClickAway {
            target: keys
        }
    }
}
