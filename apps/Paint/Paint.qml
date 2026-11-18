import "../../components"
import "../../config"
import "../../services/"
import "views"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// An image editor with layers, selections, text layers and history. The pixels live in the paint-engine
// helper (see PaintDoc); this window is the screen and the pointer.
ApplicationWindow {
    id: root

    function refreshActiveText() {
        const l = PaintDoc.active;
        if (!l || l.kind !== "text" || canvas.handler.editId > 0)
            return;
        textRender.render(l.id, PaintDoc.textProps((l.props && l.props.text) ?? ""), l.x, l.y, l.name);
    }

    width: 1360
    height: 860
    minimumWidth: 900
    minimumHeight: 700
    title: "Paint"
    visible: true
    color: Qt.alpha(Appearance.bgColor, Appearance.isLight ? 1 - Math.pow(1 - Config.appearance.settingsOpacity, 2) : Config.appearance.settingsOpacity)
    onClosing: Apps.close("paint")
    Component.onCompleted: {
        PaintDoc.start();
        Qt.callLater(canvas.zoomFit);
        canvas.forceActiveFocus();
    }

    Connections {
        function onRaiseRequested(id) {
            if (id === "paint") {
                root.raise();
                root.requestActivate();
            }
        }

        target: Apps
    }

    TextRender {
        id: textRender

        onRendered: (id, path, props, x, y, name) => PaintDoc.send({
                "op": "text.set",
                "layer": id,
                "props": props,
                "x0": x,
                "y0": y,
                "path": path,
                "name": name
            })
    }

    Connections {
        function onRenderText(id, props, x, y, name) {
            textRender.render(id, props, x, y, name);
        }

        target: canvas.handler
    }

    PaintActions {
        id: actions

        view: canvas
        handler: canvas.handler
        titleBar: titleBar
    }

    PaintKeys {
        window: root
        actions: actions
        canvas: canvas
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        TitleBar {
            id: titleBar

            Layout.fillWidth: true
            onAction: key => actions.act(key)
            onCloseRequested: Apps.close("paint")
        }

        OptionsBar {
            Layout.fillWidth: true
            onTextOptionChanged: root.refreshActiveText()
            onCommitRequested: canvas.handler.commitPending()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            ToolBox {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false
                visible: titleBar.showTools
                onChosen: id => PaintDoc.tool = id
            }

            CanvasView {
                id: canvas

                Layout.fillWidth: true
                Layout.fillHeight: true
                onWidthChanged: if (PaintDoc.tileVer["0_0"] === undefined)
                    Qt.callLater(zoomFit)
            }

            ColumnLayout {
                Layout.preferredWidth: 270
                Layout.minimumWidth: 270
                Layout.maximumWidth: 270
                Layout.fillWidth: false
                Layout.fillHeight: true
                visible: titleBar.showColors || titleBar.showLayers || titleBar.showHistory
                spacing: 8

                ColorsPanel {
                    Layout.fillWidth: true
                    visible: titleBar.showColors
                }

                LayersPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 250
                    Layout.minimumHeight: 170
                    visible: titleBar.showLayers
                }

                HistoryPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 110
                    Layout.minimumHeight: 90
                    visible: titleBar.showHistory
                }
            }
        }

        StatusBar {
            Layout.fillWidth: true
            zoom: canvas.zoom
            cursor: canvas.handler.cursor
            hint: ({
                    "rectSelect": "Drag to select. Ctrl adds, Alt subtracts, Shift makes a square",
                    "ellipseSelect": "Drag to select. Ctrl adds, Alt subtracts, Shift makes a circle",
                    "lasso": "Draw around what to select",
                    "wand": "Click to select a region of similar colour",
                    "moveSelected": "Drag to move the selected pixels (or the whole layer, or a text layer)",
                    "moveSel": "Drag to move the selection outline only",
                    "bucket": "Click to fill. Right click fills with the secondary colour",
                    "gradient": "Drag to draw a gradient from the primary to the secondary colour",
                    "brush": "Left button paints with the primary colour, right button with the secondary",
                    "eraser": "Drag to erase",
                    "pencil": "Drag to draw one-pixel lines",
                    "picker": "Click to take a colour. Right click sets the secondary colour",
                    "clone": "Ctrl+click picks the source, then paint to copy it",
                    "recolor": "Drag over the secondary colour to turn it into the primary colour",
                    "text": "Click to type. Click a text again to edit it",
                    "line": "Drag a line, then drag the dots to bend it. Enter finishes",
                    "shape": "Drag a shape, then drag the dots to adjust it. Enter finishes",
                    "zoom": "Click to zoom in, right click to zoom out",
                    "pan": "Drag to move around. Space does this in any tool"
                })[PaintDoc.tool] ?? ""
            onZoomIn: canvas.zoomCentered(1.25)
            onZoomOut: canvas.zoomCentered(1 / 1.25)
            onZoomFit: canvas.zoomFit()
            onZoomActual: canvas.zoomActual()
        }
    }

    ClickAway {
        target: canvas
    }
}
