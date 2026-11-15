import "../../config/"
import "../../components"
import "../../services" as Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Clipboard history that opens at the mouse pointer, like Win+V.
// bind = $mainMod, V, global, quickshell:clipboard
Scope {
    id: root

    readonly property bool open: Services.WindowManager.clipboardVisible
    readonly property int panelWidth: 400
    readonly property int maxHeight: 500
    readonly property int edgeGap: 8
    // pointer position inside the screen the menu opens on
    property real pointerX: 0
    property real pointerY: 0
    property var targetScreen: Quickshell.screens[0]

    function toggle() {
        if (open)
            Services.WindowManager.clipboardVisible = false;
        else
            cursorProc.running = true;
    }

    function show(x, y) {
        const screens = Quickshell.screens;
        let s = screens[0];
        for (const c of screens) {
            if (x >= c.x && x < c.x + c.width && y >= c.y && y < c.y + c.height)
                s = c;
        }
        targetScreen = s;
        pointerX = x - s.x;
        pointerY = y - s.y;
        Services.Clipboard.refresh();
        Services.WindowManager.clipboardVisible = true;
    }

    GlobalShortcut {
        name: "clipboard"
        onPressed: root.toggle()
    }

    Process {
        id: cursorProc

        command: ["hyprctl", "cursorpos"]

        stdout: StdioCollector {
            onStreamFinished: {
                const m = this.text.match(/(-?\d+),\s*(-?\d+)/);
                root.show(m ? parseInt(m[1]) : 0, m ? parseInt(m[2]) : 0);
            }
        }
    }

    PanelWindow {
        id: window

        // pinned items first, then the history; both narrowed by the search text
        property var items: []
        property int currentIndex: -1
        readonly property bool shown: root.open && backingWindowVisible
        readonly property real cardHeight: Math.min(root.maxHeight, 12 + 44 + 8 + (items.length > 0 ? list.contentHeight : 96) + 8 + hint.implicitHeight + 12)

        function close() {
            Services.WindowManager.clipboardVisible = false;
        }

        function rebuild(keepPosition) {
            const q = searchField.text.trim().toLowerCase();
            const match = e => q === "" || e.preview.toLowerCase().includes(q) || (e.image && "image".includes(q));
            const y = list.contentY;
            items = Services.Clipboard.pins.filter(match).concat(Services.Clipboard.unpinned.filter(match));
            if (keepPosition) {
                currentIndex = Math.min(currentIndex, items.length - 1);
                list.contentY = Math.max(0, Math.min(y, list.contentHeight - list.height));
            } else {
                currentIndex = items.length > 0 ? 0 : -1;
                list.positionViewAtBeginning();
            }
        }

        function move(delta) {
            if (items.length === 0)
                return;
            currentIndex = Math.max(0, Math.min(items.length - 1, currentIndex + delta));
            list.positionViewAtIndex(currentIndex, ListView.Contain);
        }

        function activate(i) {
            const e = items[i];
            if (!e)
                return;
            // closing first gives the focus back to the window that receives the paste
            close();
            Services.Clipboard.paste(e);
        }

        screen: root.targetScreen
        visible: root.open
        color: "transparent"
        implicitWidth: root.panelWidth
        implicitHeight: root.maxHeight
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // top-left corner at the pointer, pushed back in if it would leave the screen
        margins.left: Math.max(root.edgeGap, Math.min(root.pointerX, (screen?.width ?? 0) - root.panelWidth - root.edgeGap))
        margins.top: Math.max(root.edgeGap, Math.min(root.pointerY, (screen?.height ?? 0) - cardHeight - root.edgeGap))
        onVisibleChanged: {
            if (visible) {
                searchField.text = "";
                rebuild(false);
                searchField.forceActiveFocus();
            }
        }

        anchors {
            top: true
            left: true
        }

        mask: Region {
            item: card
        }

        // click anywhere else to dismiss
        HyprlandFocusGrab {
            windows: [window]
            active: window.visible
            onCleared: window.close()
        }

        Connections {
            function onHistoryChanged() {
                window.rebuild(true);
            }

            function onPinsChanged() {
                window.rebuild(true);
            }

            target: Services.Clipboard
        }

        Rectangle {
            id: card

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: window.cardHeight
            // outer radius = row radius (16) + padding (12)
            radius: 28
            color: Appearance.panelColor
            border.width: 1
            border.color: Appearance.hairlineColor
            opacity: window.shown ? 1 : 0
            clip: true

            // quick fade in once mapped; closing is immediate so the paste lands without delay
            Behavior on opacity {
                enabled: root.open

                NumberAnimation {
                    duration: 90
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // --- search field ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 22
                    color: Appearance.surfaceColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 6
                        spacing: 10

                        MaterialSymbol {
                            icon: "search"
                            color: Appearance.mutedColor
                            font.pixelSize: 20
                        }

                        TextField {
                            id: searchField

                            // keeps word autocomplete (and its Tab) out of the search
                            inputMethodHints: Qt.ImhSensitiveData

                            Layout.fillWidth: true
                            color: Appearance.fgColor
                            placeholderText: "Search clipboard"
                            placeholderTextColor: Appearance.mutedColor
                            font.family: Appearance.fontFamily
                            font.pixelSize: 15
                            selectionColor: Appearance.accentColor
                            selectedTextColor: Appearance.accentContrastColor
                            selectByMouse: true
                            background: null
                            onTextChanged: window.rebuild(false)
                            Keys.onPressed: event => {
                                const current = window.items[window.currentIndex];
                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    window.move(1);
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                    window.move(-1);
                                } else if (event.key === Qt.Key_PageDown) {
                                    window.move(5);
                                } else if (event.key === Qt.Key_PageUp) {
                                    window.move(-5);
                                } else if (event.key === Qt.Key_Escape) {
                                    window.close();
                                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                    window.activate(window.currentIndex);
                                } else if (event.key === Qt.Key_Delete && current && (event.modifiers & Qt.ShiftModifier || searchField.cursorPosition === searchField.length)) {
                                    // plain Delete still edits the search text while there is text after the cursor
                                    Services.Clipboard.remove(current);
                                } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier) && current) {
                                    Services.Clipboard.togglePin(current);
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }

                        IconButton {
                            icon: "delete_sweep"
                            size: 32
                            iconSize: 19
                            visible: Services.Clipboard.history.length > 0
                            onClicked: Services.Clipboard.wipe()
                        }
                    }
                }

                // --- entries ---
                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: window.items.length > 0
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: window.items

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool pinned: modelData.key !== undefined
                        readonly property bool selected: window.currentIndex === index
                        readonly property bool active: selected || hover.hovered

                        width: list.width
                        height: modelData.image ? 104 : Math.max(48, label.implicitHeight + 26)
                        radius: 16
                        color: active ? Appearance.surfaceHighColor : Appearance.surfaceColor
                        border.width: selected ? 1 : 0
                        border.color: Qt.alpha(Appearance.accentColor, 0.5)
                        Component.onCompleted: {
                            if (modelData.image && !pinned)
                                Services.Clipboard.requestThumb(modelData.id);
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animFast
                            }
                        }

                        HoverHandler {
                            id: hover
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.activate(row.index)
                        }

                        StyledText {
                            id: label

                            anchors.left: parent.left
                            anchors.right: actions.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 6
                            visible: !row.modelData.image
                            text: row.modelData.image ? "" : row.modelData.preview
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.pixelSize: 13
                        }

                        Image {
                            anchors.left: parent.left
                            anchors.right: actions.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            visible: row.modelData.image
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            horizontalAlignment: Image.AlignLeft
                            sourceSize.height: 200
                            source: {
                                if (!row.modelData.image)
                                    return "";
                                if (row.pinned)
                                    return "file://" + Services.Clipboard.pinPath(row.modelData.key);
                                return Services.Clipboard.thumbs[row.modelData.id] ? Services.Clipboard.thumbPath(row.modelData.id) : "";
                            }
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 12
                            anchors.bottomMargin: 9
                            visible: row.modelData.image
                            text: row.modelData.meta || ""
                            color: Appearance.mutedColor
                            font.pixelSize: 11
                        }

                        Row {
                            id: actions

                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 8
                            anchors.topMargin: 9
                            spacing: 2

                            IconButton {
                                icon: "keep"
                                size: 30
                                iconSize: 18
                                toggled: row.pinned
                                opacity: row.active || row.pinned ? 1 : 0
                                onClicked: Services.Clipboard.togglePin(row.modelData)
                            }

                            IconButton {
                                icon: "close"
                                size: 30
                                iconSize: 18
                                opacity: row.active ? 1 : 0
                                onClicked: Services.Clipboard.remove(row.modelData)
                            }
                        }
                    }
                }

                // --- empty state ---
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: window.items.length === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "content_paste_off"
                            color: Appearance.mutedColor
                            font.pixelSize: 28
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: searchField.text.trim() !== "" ? "No matches" : "Nothing copied yet"
                            color: Appearance.mutedColor
                            font.pixelSize: 13
                        }
                    }
                }

                StyledText {
                    id: hint

                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Enter paste  ·  Ctrl+P pin  ·  Del delete"
                    color: Appearance.mutedColor
                    font.pixelSize: 11
                }
            }
        }
    }
}
