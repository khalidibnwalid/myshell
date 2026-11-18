import "../../components"
import "../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// What the menus, the buttons and the shortcuts do, and the dialogs they ask with.
Item {
    id: root

    // the window's canvas view and tool handler
    property var view: null
    property var handler: null
    property var titleBar: null

    readonly property var amounts: ({
            "brightness": {
                "title": "Brightness",
                "from": -100,
                "to": 100,
                "value": 20,
                "scale": 0.01
            },
            "contrast": {
                "title": "Contrast",
                "from": -100,
                "to": 100,
                "value": 20,
                "scale": 0.01
            },
            "saturation": {
                "title": "Saturation",
                "from": -100,
                "to": 300,
                "value": 40,
                "scale": 0.01
            },
            "hue": {
                "title": "Hue shift (degrees)",
                "from": -180,
                "to": 180,
                "value": 30,
                "scale": 1
            },
            "posterize": {
                "title": "Posterize (levels)",
                "from": 2,
                "to": 16,
                "value": 4,
                "scale": 1
            },
            "noise": {
                "title": "Add noise",
                "from": 1,
                "to": 100,
                "value": 25,
                "scale": 0.01
            },
            "blur": {
                "title": "Blur (radius)",
                "from": 1,
                "to": 60,
                "value": 4,
                "scale": 1
            },
            "sharpen": {
                "title": "Sharpen",
                "from": 1,
                "to": 10,
                "value": 2,
                "scale": 0.5
            },
            "pixelate": {
                "title": "Pixelate (block size)",
                "from": 2,
                "to": 120,
                "value": 8,
                "scale": 1
            }
        })
    property string amountKind: ""
    property real amountValue: 0
    property var afterConfirm: null
    property string sizeMode: "new"
    property int sizeW: 1280
    property int sizeH: 720
    property bool keepRatio: true
    property string newBackground: "white"
    property string anchorMode: "center"
    property string fileKind: "open"

    function act(key) {
        if (key.indexOf("adj:") === 0) {
            send({
                "op": "adjust",
                "kind": key.slice(4),
                "layer": PaintDoc.activeId,
                "label": key.slice(4)
            });
            return;
        }
        if (key.indexOf("amt:") === 0) {
            amountKind = key.slice(4);
            amountValue = amounts[amountKind].value;
            amountDialog.open();
            return;
        }
        if (key.indexOf("panel:") === 0) {
            const n = "show" + key.charAt(6).toUpperCase() + key.slice(7);
            titleBar[n] = !titleBar[n];
            return;
        }
        switch (key) {
        case "new":
            guard(() => {
                sizeMode = "new";
                sizeW = 1280;
                sizeH = 720;
                sizeDialog.open();
            });
            break;
        case "open":
            guard(() => openFileDialog("open"));
            break;
        case "import":
            openFileDialog("import");
            break;
        case "save":
            if (PaintDoc.path !== "")
                PaintDoc.saveTo(PaintDoc.path);
            else
                openFileDialog("save");
            break;
        case "saveAs":
            openFileDialog("save");
            break;
        case "close":
            Apps.close("paint");
            break;
        case "undo":
        case "redo":
            handler.finishEdits();
            send({
                "op": key
            });
            break;
        case "cut":
        case "copy":
            if (PaintDoc.sel === null && key === "cut")
                break;
            send({
                "op": "edit",
                "kind": key
            });
            if (PaintDoc.sel === null)
                PaintDoc.say("Whole layer copied: select something to copy only a part");
            break;
        case "paste":
            pasteProc.running = true;
            break;
        case "clear":
            send({
                "op": "edit",
                "kind": "clear"
            });
            break;
        case "fillsel":
            send({
                "op": "edit",
                "kind": "fillsel",
                "color": PaintDoc.hex8(PaintDoc.primary)
            });
            break;
        case "selectAll":
            send({
                "op": "sel",
                "kind": "all"
            });
            break;
        case "deselect":
            send({
                "op": "sel",
                "kind": "none"
            });
            break;
        case "invertSel":
            send({
                "op": "sel",
                "kind": "invert"
            });
            break;
        case "crop":
            send({
                "op": "image",
                "kind": "crop",
                "label": "Crop to selection",
                "icon": "crop"
            });
            Qt.callLater(view.zoomFit);
            break;
        case "resize":
            sizeMode = "resize";
            sizeW = PaintDoc.docW;
            sizeH = PaintDoc.docH;
            sizeDialog.open();
            break;
        case "canvasSize":
            sizeMode = "canvas";
            sizeW = PaintDoc.docW;
            sizeH = PaintDoc.docH;
            sizeDialog.open();
            break;
        case "flipH":
        case "flipV":
        case "rotate90":
        case "rotate270":
        case "rotate180":
            send({
                "op": "image",
                "kind": key,
                "label": ({
                        "flipH": "Flip horizontal",
                        "flipV": "Flip vertical",
                        "rotate90": "Rotate 90° clockwise",
                        "rotate270": "Rotate 90° counter-clockwise",
                        "rotate180": "Rotate 180°"
                    })[key]
            });
            if (key.indexOf("rotate90") === 0 || key === "rotate270")
                Qt.callLater(view.zoomFit);
            break;
        case "flatten":
            send({
                "op": "flatten"
            });
            break;
        case "layerAdd":
            PaintDoc.layerOp("add");
            break;
        case "layerDup":
            PaintDoc.layerOp("dup");
            break;
        case "layerDelete":
            PaintDoc.layerOp("delete");
            break;
        case "layerUp":
            PaintDoc.layerOp("up");
            break;
        case "layerDown":
            PaintDoc.layerOp("down");
            break;
        case "layerMerge":
            PaintDoc.layerOp("merge");
            break;
        case "zoomIn":
            view.zoomCentered(1.25);
            break;
        case "zoomOut":
            view.zoomCentered(1 / 1.25);
            break;
        case "zoomFit":
            view.zoomFit();
            break;
        case "zoomActual":
            view.zoomActual();
            break;
        }
    }

    // flushes what is still being edited, then sends
    function send(cmd) {
        handler.commitPending();
        handler.commitText();
        PaintDoc.send(cmd);
    }

    function guard(proceed) {
        if (!PaintDoc.modified) {
            proceed();
            return;
        }
        afterConfirm = proceed;
        confirmDialog.open();
    }

    function openFileDialog(kind) {
        fileKind = kind;
        fileLoader.active = true;
        Qt.callLater(() => fileLoader.item.open());
    }

    Process {
        id: pasteProc

        command: ["sh", "-c", "command -v wl-paste >/dev/null && wl-paste -t image/png > \"$1\" 2>/dev/null; [ -s \"$1\" ] && echo yes", "sh", PaintDoc.tileDir + "/paste.png"]
        stdout: StdioCollector {
            onStreamFinished: {
                const view = root.view;
                root.send({
                    "op": "edit",
                    "kind": "paste",
                    "path": text.trim() === "yes" ? PaintDoc.tileDir + "/paste.png" : "",
                    "x0": Math.max(0, Math.round(view.docX(0))),
                    "y0": Math.max(0, Math.round(view.docY(0)))
                });
                PaintDoc.tool = "moveSelected";
            }
        }
    }

    Loader {
        id: fileLoader

        active: false

        sourceComponent: FileDialog {
            title: root.fileKind === "save" ? "Save the image" : (root.fileKind === "import" ? "Open an image as a layer" : "Open an image")
            fileMode: root.fileKind === "save" ? FileDialog.SaveFile : FileDialog.OpenFile
            defaultSuffix: "ora"
            nameFilters: root.fileKind === "save" ? ["Layered image (*.ora)", "PNG (*.png)", "JPEG (*.jpg *.jpeg)", "GIF (*.gif)"] : ["Images (*.png *.jpg *.jpeg *.gif *.ora)", "All files (*)"]
            onAccepted: {
                if (root.fileKind === "save")
                    PaintDoc.saveTo(selectedFile.toString());
                else if (root.fileKind === "import")
                    PaintDoc.importFile(selectedFile.toString());
                else
                    PaintDoc.openFile(selectedFile.toString());
            }
        }
    }

    ModalDialog {
        id: confirmDialog

        title: "Unsaved changes"
        buttons: [
            {
                "text": "Cancel",
                "key": "cancel"
            },
            {
                "text": "Discard",
                "key": "discard"
            },
            {
                "text": "Save",
                "key": "save",
                "primary": true
            }
        ]
        onButtonClicked: key => {
            if (key === "discard" && root.afterConfirm)
                root.afterConfirm();
            else if (key === "save") {
                if (PaintDoc.path !== "") {
                    PaintDoc.saveTo(PaintDoc.path);
                    if (root.afterConfirm)
                        root.afterConfirm();
                } else {
                    root.openFileDialog("save");
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "“" + PaintDoc.docName + "” has changes that are not saved."
            color: Appearance.mutedColor
        }
    }

    ModalDialog {
        id: sizeDialog

        title: root.sizeMode === "new" ? "New image" : (root.sizeMode === "resize" ? "Resize image" : "Canvas size")
        buttons: [
            {
                "text": "Cancel",
                "key": "cancel"
            },
            {
                "text": root.sizeMode === "new" ? "Create" : "Apply",
                "key": "ok",
                "primary": true
            }
        ]
        onButtonClicked: key => {
            if (key !== "ok")
                return;
            if (root.sizeMode === "new") {
                PaintDoc.newDoc(root.sizeW, root.sizeH, root.newBackground);
            } else {
                root.send({
                    "op": "image",
                    "kind": root.sizeMode === "resize" ? "resize" : "canvas",
                    "w": root.sizeW,
                    "h": root.sizeH,
                    "mode": root.sizeMode === "resize" ? "smooth" : root.anchorMode,
                    "label": root.sizeMode === "resize" ? "Resize image" : "Canvas size",
                    "icon": "photo_size_select_large"
                });
                Qt.callLater(root.view.zoomFit);
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            NumberStepper {
                label: "Width"
                value: root.sizeW
                from: 1
                to: 16000
                step: 10
                fieldWidth: 64
                onChanged: v => {
                    const r = root.sizeH / root.sizeW;
                    root.sizeW = v;
                    if (root.keepRatio && root.sizeMode === "resize")
                        root.sizeH = Math.max(1, Math.round(v * r));
                }
            }

            NumberStepper {
                label: "Height"
                value: root.sizeH
                from: 1
                to: 16000
                step: 10
                fieldWidth: 64
                onChanged: v => {
                    const r = root.sizeW / root.sizeH;
                    root.sizeH = v;
                    if (root.keepRatio && root.sizeMode === "resize")
                        root.sizeW = Math.max(1, Math.round(v * r));
                }
            }
        }

        PillButton {
            visible: root.sizeMode === "resize"
            text: "Keep the proportions"
            icon: root.keepRatio ? "link" : "link_off"
            toggled: root.keepRatio
            onClicked: root.keepRatio = !root.keepRatio
        }

        Segmented {
            visible: root.sizeMode === "new"
            Layout.fillWidth: true
            model: [
                {
                    "label": "White",
                    "value": "white"
                },
                {
                    "label": "Primary colour",
                    "value": "primary"
                },
                {
                    "label": "Transparent",
                    "value": "transparent"
                }
            ]
            value: root.newBackground
            onSelected: v => root.newBackground = v
        }

        Segmented {
            visible: root.sizeMode === "canvas"
            Layout.fillWidth: true
            model: [
                {
                    "label": "Top left",
                    "value": "topleft"
                },
                {
                    "label": "Centre",
                    "value": "center"
                },
                {
                    "label": "Bottom right",
                    "value": "bottomright"
                }
            ]
            value: root.anchorMode
            onSelected: v => root.anchorMode = v
        }
    }

    ModalDialog {
        id: amountDialog

        readonly property var spec: root.amounts[root.amountKind] ?? ({
                "title": "",
                "from": 0,
                "to": 1,
                "value": 0,
                "scale": 1
            })

        title: spec.title
        buttons: [
            {
                "text": "Cancel",
                "key": "cancel"
            },
            {
                "text": "Apply",
                "key": "ok",
                "primary": true
            }
        ]
        onButtonClicked: key => {
            if (key === "ok")
                root.send({
                    "op": "adjust",
                    "kind": root.amountKind,
                    "layer": PaintDoc.activeId,
                    "amount": root.amountValue * spec.scale,
                    "label": spec.title.split(" (")[0]
                });
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            PillSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                icon: "tune"
                value: (root.amountValue - amountDialog.spec.from) / (amountDialog.spec.to - amountDialog.spec.from)
                onDragged: v => root.amountValue = Math.round(amountDialog.spec.from + v * (amountDialog.spec.to - amountDialog.spec.from))
            }

            NumberStepper {
                value: root.amountValue
                from: amountDialog.spec.from
                to: amountDialog.spec.to
                fieldWidth: 56
                onChanged: v => root.amountValue = v
            }
        }
    }
}
