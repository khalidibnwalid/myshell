import "../../config/"
import "../../components"
import "../../services" as Services
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Scope {
    // bind = $mainMod, SPACE, global, quickshell:search
    GlobalShortcut {
        name: "search"
        onPressed: Services.WindowManager.toggleSearchVisible()
    }

    // click anywhere else to dismiss; the bar stays usable so its search button can toggle
    HyprlandFocusGrab {
        windows: [...searchWindows.instances, ...Services.WindowManager.barWindows, ...Services.WindowManager.barPopups]
        active: Services.WindowManager.searchVisible
        onCleared: Services.WindowManager.searchVisible = false
    }

    Variants {
        id: searchWindows

        model: Quickshell.screens

        PanelWindow {
            id: panelWindow

            // flat result list: apps first (shown as tiles), the rest as rows
            property var results: []
            readonly property var tileResults: results.filter(r => r && r.type === "app").slice(0, 4)
            readonly property var rowResults: results.filter(r => r && tileResults.indexOf(r) < 0).slice(0, 6)
            readonly property var ordered: tileResults.concat(rowResults)
            property int currentIndex: -1
            // where the pointer was last seen; results that appear under a pointer that did not move are not selected
            property point lastPointer: Qt.point(-1, -1)

            function pointerMoved(area, mouse, index) {
                const p = area.mapToItem(null, mouse.x, mouse.y);
                const moved = lastPointer.x >= 0 && (p.x !== lastPointer.x || p.y !== lastPointer.y);
                lastPointer = p;
                if (moved)
                    currentIndex = index;
            }

            function typeLabel(r) {
                switch (r.type) {
                case "app":
                    return "App";
                case "folder":
                    return "Folder";
                case "file":
                    return "File";
                default:
                    return r.description || "";
                }
            }

            function initials(name) {
                return (name || "?").substring(0, 2);
            }

            function iconSource(img) {
                if (!img)
                    return "";
                if (img.startsWith("file://"))
                    return img;
                if (img.startsWith("/"))
                    return "file://" + img;
                return Services.Icons.path(img, true);
            }

            function updateResults(newResults) {
                panelWindow.results = newResults || [];
                panelWindow.currentIndex = panelWindow.ordered.length > 0 ? 0 : -1;
            }

            function close() {
                Services.WindowManager.searchVisible = false;
            }

            // the file or folder a result stands for, if it is one on disk (Ctrl + Enter shows it in its folder)
            function pathOf(r) {
                if (!r)
                    return "";
                if (r.type === "file" || r.type === "folder")
                    return r.id;
                const t = String(r.target || "");
                if (r.type === "provider" && (t.startsWith("/") || t.startsWith("file://")))
                    return t.startsWith("file://") ? decodeURIComponent(t.substring(7)) : t;
                return "";
            }

            // opens the file manager on the folder with the file selected (FileManager1, which Nautilus,
            // Dolphin and others offer), or just the folder when nothing answers
            function reveal(i) {
                const path = pathOf(ordered[i]);
                if (path === "")
                    return false;
                const uri = "file://" + path.split("/").map(p => encodeURIComponent(p).replace(/'/g, "%27")).join("/");
                const dir = path.replace(/\/[^/]*\/?$/, "") || "/";
                Quickshell.execDetached(["sh", "-c", "gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems \"['$1']\" '' >/dev/null 2>&1 || xdg-open \"$2\"", "sh", uri, dir]);
                close();
                return true;
            }

            function activate(i) {
                const r = ordered[i];
                if (!r)
                    return;
                if (r.execute) {
                    r.execute();
                    close();
                } else if (r.complete) {
                    // e.g. picking a bang from the list fills it in
                    searchField.text = r.complete;
                }
            }

            // The window keeps one fixed size; only the card inside animates,
            // so typing never resizes the surface.
            readonly property bool open: Services.WindowManager.searchVisible
            property real cardHeight: content.implicitHeight + 24
            // animate only once the surface is on screen
            readonly property bool shown: open && backingWindowVisible

            color: "transparent"
            implicitWidth: 664
            implicitHeight: 580
            focusable: true
            // mapped from opening until the fade-out is done (a binding on closeTimer.running dropped
            // to false for an instant before the timer restarted, which made the closing flicker)
            property bool held: false

            visible: open || held
            onOpenChanged: {
                if (open) {
                    closeTimer.stop();
                    held = true;
                    searchField.text = "";
                    panelWindow.updateResults([]);
                    searchField.forceActiveFocus();
                } else {
                    closeTimer.restart();
                }
            }

            mask: Region {
                item: card
            }

            Timer {
                id: closeTimer

                // a little longer than the fade-out below, so it is not cut off
                interval: 130
                onTriggered: panelWindow.held = false
            }

            Behavior on cardHeight {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeStandard
                }
            }

            Connections {
                function onSearchFinished(newResults) {
                    panelWindow.updateResults(newResults);
                }

                target: Services.Search
            }

            // card
            Rectangle {
                id: card

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: panelWindow.cardHeight
                // outer radius = inner radius (29) + padding (12)
                radius: 41
                color: Appearance.panelColor
                border.width: 1
                border.color: Appearance.hairlineColor
                opacity: panelWindow.shown ? 1 : 0
                clip: true

                // drops in a few pixels while fading
                transform: Translate {
                    y: panelWindow.shown ? 0 : -10

                    Behavior on y {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.easeStandard
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 110
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.easeFade
                    }
                }
            }

            ColumnLayout {
                id: content

                parent: card
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 12

                // --- search field ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: 29
                    color: Appearance.surfaceColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22
                        anchors.rightMargin: 9
                        spacing: 12

                        MaterialSymbol {
                            // thin, slightly larger and muted so it sits quietly next to the text
                            icon: "search"
                            color: Appearance.mutedColor
                            font.pixelSize: 26
                            font.weight: Font.Light
                            renderType: Text.QtRendering
                        }

                        TextField {
                            id: searchField

                            // keeps word autocomplete (and its Tab) out of the search
                            inputMethodHints: Qt.ImhSensitiveData

                            // inline bang completion: "!y" shows a ghost "t", Tab accepts it
                            readonly property string completion: cursorPosition === length ? Services.Search.bangCompletion(text) : ""

                            StyledText {
                                x: searchField.leftPadding + searchField.contentWidth
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.completion !== ""
                                text: searchField.completion
                                color: Appearance.mutedColor
                                font: searchField.font
                                opacity: 0.7
                            }

                            StyledText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.completion !== ""
                                text: "Tab"
                                color: Appearance.mutedColor
                                font.pixelSize: 12
                            }

                            Layout.fillWidth: true
                            color: Appearance.fgColor
                            placeholderText: "Search apps, files, web  ·  !yt  ·  !yt! private"
                            placeholderTextColor: Appearance.mutedColor
                            font.family: Appearance.fontFamily
                            font.pixelSize: 19
                            font.weight: Font.Medium
                            selectionColor: Appearance.accentColor
                            selectedTextColor: Appearance.accentContrastColor
                            selectByMouse: true
                            background: null
                            Keys.onPressed: event => {
                                const n = panelWindow.ordered.length;
                                if (event.key === Qt.Key_Tab && searchField.completion !== "") {
                                // accept the suggested bang
                                searchField.text = searchField.text + searchField.completion + " ";
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    panelWindow.currentIndex = Math.min(n - 1, panelWindow.currentIndex + 1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                    panelWindow.currentIndex = Math.max(0, panelWindow.currentIndex - 1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    panelWindow.close();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && (event.modifiers & Qt.ControlModifier)) {
                                    panelWindow.reveal(panelWindow.currentIndex);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                    panelWindow.activate(panelWindow.currentIndex);
                                    event.accepted = true;
                                }
                            }
                            onTextChanged: Services.Search.performSearch(text)
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: hint.implicitWidth + 32
                            implicitHeight: 40
                            radius: 20
                            color: Appearance.surfaceHighColor

                            StyledText {
                                id: hint

                                anchors.centerIn: parent
                                // the key that matters for the picked row, else how to open the launcher
                                text: panelWindow.pathOf(panelWindow.ordered[panelWindow.currentIndex]) !== "" ? "Ctrl + Enter: show in folder" : "Super + Space"
                                color: Appearance.mutedColor
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                // --- app tiles ---
                RowLayout {
                    Layout.fillWidth: true
                    visible: panelWindow.tileResults.length > 0
                    spacing: 6

                    Repeater {
                        model: panelWindow.tileResults

                        delegate: Rectangle {
                            id: tile

                            required property var modelData
                            required property int index
                            readonly property bool selected: panelWindow.currentIndex === index
                            readonly property bool highlighted: selected

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 108
                            radius: 29
                            color: highlighted ? Qt.alpha(Appearance.accentColor, 0.2) : Appearance.surfaceColor
                            border.width: highlighted ? 2 : 0
                            border.color: highlighted ? Qt.alpha(Appearance.accentColor, 0.5) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animFast
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.easeFade
                                }
                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Appearance.animFast
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.easeFade
                                }
                            }

                            Behavior on border.width {
                                NumberAnimation {
                                    duration: Appearance.animFast
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.easeStandard
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 16
                                spacing: 9

                                // icon: real app icon, initials circle as fallback
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 44

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 22
                                        visible: tileImg.status !== Image.Ready
                                        color: Appearance.surfaceHighColor

                                        // our own features carry a Material symbol, not a system app icon
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: !!tile.modelData?.symbol
                                            icon: tile.modelData?.symbol || ""
                                            fill: 1
                                            font.pixelSize: 26
                                            color: Appearance.accentColor
                                        }

                                        StyledText {
                                            anchors.centerIn: parent
                                            visible: !tile.modelData?.symbol
                                            text: panelWindow.initials(tile.modelData?.name)
                                            color: Appearance.fgColor
                                            font.pixelSize: 15
                                            font.weight: Font.Bold
                                        }
                                    }

                                    Image {
                                        id: tileImg

                                        anchors.fill: parent
                                        source: panelWindow.iconSource(tile.modelData?.image)
                                        sourceSize: Qt.size(112, 112)
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: tile.modelData?.name
                                    elide: Text.ElideRight
                                    color: Appearance.fgColor
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: tileMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: mouse => panelWindow.pointerMoved(tileMouse, mouse, tile.index)
                                onClicked: panelWindow.activate(tile.index)
                            }
                        }
                    }
                }

                // --- result rows ---
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: panelWindow.rowResults.length > 0
                    spacing: 3

                    Repeater {
                        model: panelWindow.rowResults

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property int flatIndex: panelWindow.tileResults.length + index
                            readonly property bool selected: panelWindow.currentIndex === flatIndex
                            // apps and web results carry a real icon
                            // a picture of the file itself: a thumbnail, the image, an album cover
                            readonly property bool preview: (modelData?.type === "file" || modelData?.type === "provider") && !!modelData?.preview
                            readonly property bool hasImage: (modelData?.type === "app" || modelData?.type === "web" || modelData?.type === "provider") && !!modelData?.image

                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            topLeftRadius: index === 0 ? 29 : 6
                            topRightRadius: index === 0 ? 29 : 6
                            bottomLeftRadius: index === panelWindow.rowResults.length - 1 ? 29 : 6
                            bottomRightRadius: index === panelWindow.rowResults.length - 1 ? 29 : 6
                            color: selected ? Appearance.surfaceHighColor : Appearance.surfaceColor

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animFast
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.easeFade
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 22
                                spacing: 14

                                Rectangle {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    radius: row.preview && previewImg.status === Image.Ready ? 10 : 18
                                    // a colour result shows the colour itself
                                    color: row.modelData?.swatch || Appearance.surfaceHighColor
                                    border.width: row.modelData?.swatch ? 1 : 0
                                    border.color: Qt.alpha(Appearance.fgColor, 0.2)

                                    // the file's own picture, rounded
                                    Item {
                                        anchors.fill: parent
                                        visible: row.preview && previewImg.status === Image.Ready

                                        Image {
                                            id: previewImg

                                            anchors.fill: parent
                                            asynchronous: true
                                            source: row.preview ? panelWindow.iconSource(row.modelData?.preview) : ""
                                            sourceSize: Qt.size(96, 96)
                                            fillMode: Image.PreserveAspectCrop
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: previewMask
                                            }
                                        }

                                        Rectangle {
                                            id: previewMask

                                            anchors.fill: parent
                                            radius: 10
                                            visible: false
                                            layer.enabled: true
                                        }
                                    }

                                    Image {
                                        id: rowImg

                                        anchors.centerIn: parent
                                        width: 20
                                        height: 20
                                        visible: status === Image.Ready && row.hasImage && !(row.preview && previewImg.status === Image.Ready)
                                        source: row.hasImage ? panelWindow.iconSource(row.modelData?.image) : ""
                                        sourceSize: Qt.size(48, 48)
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: !rowImg.visible && !(row.preview && previewImg.status === Image.Ready) && !row.modelData?.swatch
                                        icon: row.modelData?.type === "folder" ? "folder" : (row.modelData?.icon || "apps")
                                        font.pixelSize: 18
                                        color: Appearance.fgColor
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: row.modelData?.name
                                        elide: Text.ElideRight
                                        color: Appearance.fgColor
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: row.modelData?.type === "app" || row.modelData?.type === "file" || row.modelData?.type === "folder" ? (row.modelData?.description || "").replace(/^\/home\/[^/]+/, "~") : ""
                                        elide: Text.ElideMiddle
                                        color: Appearance.mutedColor
                                        font.pixelSize: 12
                                    }
                                }

                                StyledText {
                                    text: panelWindow.typeLabel(row.modelData)
                                    color: Appearance.mutedColor
                                    font.pixelSize: 12
                                }
                            }

                            MouseArea {
                                id: rowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: mouse => panelWindow.pointerMoved(rowMouse, mouse, row.flatIndex)
                                onClicked: panelWindow.activate(row.flatIndex)
                            }
                        }
                    }
                }
            }
        }
    }
}
