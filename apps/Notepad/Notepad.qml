import "../../components"
import "../../config"
import "../../services/"
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Notes in their own window. Notes are saved as you type.
// bind = $mainMod, N, global, quickshell:notepad
ApplicationWindow {
    id: root

    property string query: ""
    // the list of notes can be folded away (Ctrl+B or the button) to leave only the editor
    property bool sidebarOpen: true
    // "edit" writes the note, "view" shows it as Markdown
    property string mode: "edit"
    // dragged by the handle on its right edge
    property real sidebarWidth: 260
    readonly property var current: Notes.current
    // a note is changed in place, so these look at the list to notice every keystroke
    readonly property string noteText: {
        Notes.notes;
        return current ? current.text : "";
    }
    readonly property bool notePinned: {
        Notes.notes;
        return current ? current.pinned : false;
    }
    readonly property string notePath: {
        Notes.notes;
        return current ? current.path : "";
    }
    readonly property int words: noteText.trim() === "" ? 0 : noteText.trim().split(/\s+/).length

    function openWindow() {
        WindowManager.openNotepad();
    }

    // Ctrl+S: into the file the note came from, or ask where when it has none
    function saveNote(asNew) {
        if (!current)
            return;
        if (asNew || !Notes.saveFile(Notes.currentId)) {
            const name = Notes.titleOf(current).replace(/[\/:*?"<>|]/g, "_").slice(0, 60);
            const markdown = /^\s{0,3}#{1,6}\s/m.test(noteText);
            saveDialog.currentFile = "file://" + Quickshell.env("HOME") + "/" + (name || "Note") + (markdown ? ".md" : ".txt");
            saveDialog.open();
        }
    }

    function focusEditor() {
        if (current && mode === "edit")
            editor.forceActiveFocus();
    }

    width: 860
    height: 600
    minimumWidth: 560
    minimumHeight: 360
    title: "Notepad"
    visible: WindowManager.notepadVisible
    color: Qt.alpha(Appearance.bgColor, Appearance.isLight ? 1 - Math.pow(1 - Config.appearance.settingsOpacity, 2) : Config.appearance.settingsOpacity)
    onClosing: WindowManager.notepadVisible = false
    onVisibleChanged: {
        if (!visible)
            return;
        Notes.refresh();
        if (Notes.loaded && Notes.notes.length === 0)
            Notes.create();
        Qt.callLater(focusEditor);
    }

    // the first note of a fresh install
    Connections {
        function onLoadedChanged() {
            if (Notes.loaded && root.visible && Notes.notes.length === 0)
                Notes.create();
            Qt.callLater(root.focusEditor);
        }

        target: Notes
    }

    Connections {
        function onNotepadRaiseRequested() {
            root.raise();
            root.requestActivate();
            Qt.callLater(root.focusEditor);
        }

        target: WindowManager
    }

    GlobalShortcut {
        name: "notepad"
        onPressed: WindowManager.notepadVisible = !WindowManager.notepadVisible
    }

    // qs ipc call notepad toggle | open | close | create
    IpcHandler {
        function toggle(): void {
            if (WindowManager.notepadVisible)
                WindowManager.notepadVisible = false;
            else
                root.openWindow();
        }

        function open(): void {
            root.openWindow();
        }

        function close(): void {
            WindowManager.notepadVisible = false;
        }

        function openFile(path: string): void {
            root.openWindow();
            Notes.openFile(path);
            Qt.callLater(root.focusEditor);
        }

        function create(): void {
            root.openWindow();
            Notes.create();
            Qt.callLater(root.focusEditor);
        }

        target: "notepad"
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: {
            Notes.create();
            Qt.callLater(root.focusEditor);
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+V"
        onActivated: {
            root.mode = root.mode === "edit" ? "view" : "edit";
            Qt.callLater(root.focusEditor);
        }
    }

    Shortcut {
        sequence: "Ctrl+S"
        onActivated: root.saveNote(false)
    }

    Shortcut {
        sequence: "Ctrl+Shift+S"
        onActivated: root.saveNote(true)
    }

    Shortcut {
        sequence: "Ctrl+O"
        onActivated: openDialog.open()
    }

    FileDialog {
        id: openDialog

        title: "Open a text file"
        nameFilters: ["Text files (*.txt *.md *.log *.conf *.json *.qml *.sh)", "All files (*)"]
        onAccepted: {
            Notes.openFile(selectedFile.toString());
            Qt.callLater(root.focusEditor);
        }
    }

    FileDialog {
        id: saveDialog

        title: "Save the note"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Text files (*.txt *.md)", "All files (*)"]
        onAccepted: Notes.saveTo(Notes.currentId, selectedFile.toString())
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: root.sidebarOpen = !root.sidebarOpen
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.sidebarOpen
        onActivated: search.focusInput()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.query !== ""
        onActivated: {
            search.clear();
            root.query = "";
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // --- the list of notes: slides shut, the content keeps its width while it does ---
        Item {
            id: sidebar

            Layout.fillWidth: false
            Layout.fillHeight: true
            Layout.preferredWidth: root.sidebarOpen ? root.sidebarWidth : 0
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            visible: Layout.preferredWidth > 0
            clip: true

            Behavior on Layout.preferredWidth {
                // no slide while the handle is dragged, so the edge follows the pointer
                enabled: !grip.pressed

                NumberAnimation {
                    duration: Appearance.animNormal
                    easing.type: Easing.OutCubic
                }
            }

        ColumnLayout {
            x: 12
            y: 12
            width: root.sidebarWidth - 24
            height: parent.height - 24
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.topMargin: 10

                StyledText {
                    Layout.fillWidth: true
                    text: "Notes"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                IconButton {
                    icon: "left_panel_close"
                    size: 34
                    iconSize: 20
                    onClicked: root.sidebarOpen = false
                }

                IconButton {
                    icon: "add"
                    size: 34
                    onClicked: {
                        Notes.create();
                        root.focusEditor();
                    }
                }
            }

            FieldInput {
                id: search

                Layout.fillWidth: true
                placeholder: "Search notes"
                icon: "search"
                onEdited: text => root.query = text
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: list

                    readonly property var rows: {
                        Notes.notes;
                        return Notes.sorted(root.query);
                    }
                    // the order shown while a row is dragged; the rows follow it by slot
                    property var order: rows.map(n => n.id)
                    readonly property int rowHeight: 52
                    readonly property int gap: 3
                    property bool dragging: false

                    anchors.fill: parent
                    clip: true
                    contentHeight: Math.max(0, rows.length * (rowHeight + gap) - gap)
                    boundsBehavior: Flickable.StopAtBounds
                    // the page must not scroll while a note is being dragged
                    interactive: !dragging
                    onRowsChanged: order = rows.map(n => n.id)

                    Item {
                        width: list.width
                        height: list.contentHeight

                        Repeater {
                            model: list.rows

                            delegate: ListRow {
                                id: row

                                required property var modelData
                                readonly property int slot: list.order.indexOf(modelData.id)
                                property bool dragging: false
                                property real dragY: 0

                                width: list.width
                                implicitHeight: list.rowHeight
                                y: dragging ? dragY : slot * (list.rowHeight + list.gap)
                                z: dragging ? 10 : 0
                                scale: dragging ? 1.02 : 1
                                first: slot === 0
                                last: slot === list.rows.length - 1
                                active: modelData.id === Notes.currentId
                                icon: modelData.pinned ? "push_pin" : ""
                                iconFill: 1
                                title: Notes.titleOf(modelData)
                                subtitle: Notes.previewOf(modelData)
                                // room for the x, so the title never runs under it
                                trailingSpace: 22
                                onClicked: {
                                    Notes.select(modelData.id);
                                    root.focusEditor();
                                }

                                Behavior on y {
                                    enabled: !row.dragging

                                    NumberAnimation {
                                        duration: Appearance.animFast
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Appearance.animFast
                                    }
                                }

                                // drag a note to move it (not while a search narrows the list)
                                DragHandler {
                                    id: drag

                                    property real startY: 0

                                    target: null
                                    xAxis.enabled: false
                                    enabled: root.query === ""
                                    onActiveChanged: {
                                        if (active) {
                                            startY = row.y;
                                            row.dragY = row.y;
                                            row.dragging = true;
                                            list.dragging = true;
                                        } else {
                                            row.dragging = false;
                                            list.dragging = false;
                                            Notes.reorder(list.order);
                                        }
                                    }
                                    onTranslationChanged: {
                                        if (!active)
                                            return;
                                        const step = list.rowHeight + list.gap;
                                        const bottom = (list.rows.length - 1) * step;
                                        row.dragY = Math.max(0, Math.min(bottom, startY + translation.y));
                                        const want = Math.max(0, Math.min(list.rows.length - 1, Math.round(row.dragY / step)));
                                        const have = list.order.indexOf(row.modelData.id);
                                        if (want !== have) {
                                            const next = list.order.slice();
                                            next.splice(have, 1);
                                            next.splice(want, 0, row.modelData.id);
                                            list.order = next;
                                        }
                                    }
                                }

                                // x at the end of the row while it is hovered: deletes the note
                                IconButton {
                                    id: removeButton

                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: (row.hovered || removeButton.hovered) && !row.dragging
                                    icon: "close"
                                    size: 28
                                    iconSize: 16
                                    color: row.contentColor
                                    onClicked: Notes.remove(row.modelData.id)
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: list.rows.length === 0
                    text: root.query === "" ? "No notes yet" : "No note matches"
                    color: Appearance.mutedColor
                }
            }
        }

            // drag to change the width of the list
            MouseArea {
                id: grip

                property real startX: 0
                property real startWidth: 0

                anchors.right: parent.right
                width: 10
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                onPressed: mouse => {
                    startX = mapToItem(null, mouse.x, 0).x;
                    startWidth = root.sidebarWidth;
                }
                onPositionChanged: mouse => {
                    if (!pressed || !root.sidebarOpen)
                        return;
                    const w = startWidth + mapToItem(null, mouse.x, 0).x - startX;
                    // dragged well below the narrowest width: fold it away instead
                    if (w < 120)
                        root.sidebarOpen = false;
                    else
                        root.sidebarWidth = Math.max(180, Math.min(480, w));
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 48
                    radius: 1.5
                    color: Appearance.accentColor
                    opacity: grip.pressed ? 0.9 : (grip.containsMouse ? 0.5 : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }
                }
            }
        }

        // --- the editor ---
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            Layout.leftMargin: root.sidebarOpen ? 0 : 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            spacing: 10

            // the way back to the list while it is folded, and the close button
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6

                IconButton {
                    visible: !root.sidebarOpen
                    icon: "left_panel_open"
                    size: 34
                    iconSize: 20
                    onClicked: root.sidebarOpen = true
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !root.sidebarOpen
                    text: root.current ? Notes.titleOf({ "text": root.noteText }) : "Notes"
                    elide: Text.ElideRight
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Item {
                    Layout.fillWidth: true
                    visible: root.sidebarOpen
                }

                Segmented {
                    visible: root.current !== null
                    model: [
                        {
                            "label": "Edit",
                            "value": "edit"
                        },
                        {
                            "label": "View",
                            "value": "view"
                        }
                    ]
                    value: root.mode
                    onSelected: v => {
                        root.mode = v;
                        Qt.callLater(root.focusEditor);
                    }
                }

                IconButton {
                    icon: "folder_open"
                    size: 34
                    iconSize: 20
                    onClicked: openDialog.open()
                }

                IconButton {
                    visible: root.current !== null
                    icon: "save"
                    size: 34
                    iconSize: 20
                    onClicked: root.saveNote(false)
                }

                IconButton {
                    visible: root.current !== null
                    icon: "content_copy"
                    size: 34
                    iconSize: 20
                    onClicked: Quickshell.execDetached(["wl-copy", root.noteText])
                }

                IconButton {
                    visible: root.current !== null
                    icon: "push_pin"
                    size: 34
                    iconSize: 20
                    iconFill: root.notePinned ? 1 : 0
                    toggled: root.notePinned
                    onClicked: Notes.togglePin(Notes.currentId)
                }

                IconButton {
                    visible: root.current !== null
                    icon: "delete"
                    size: 34
                    iconSize: 20
                    onClicked: {
                        Notes.remove(Notes.currentId);
                        root.focusEditor();
                    }
                }

                IconButton {
                    icon: "close"
                    size: 34
                    iconSize: 20
                    onClicked: WindowManager.notepadVisible = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 20
                color: Appearance.surfaceColor

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: root.current !== null && root.mode === "edit"

                    TextArea {
                        id: editor

                        // the note changes when another is picked; typing is sent back as it comes
                        property string noteId: root.current ? root.current.id : ""

                        function load() {
                            const text = root.current ? root.current.text : "";
                            if (editor.text !== text)
                                editor.text = text;
                        }

                        onNoteIdChanged: load()
                        Component.onCompleted: load()

                        // text that changed without typing (a file opened into the note)
                        Connections {
                            function onNotesChanged() {
                                if (!editor.activeFocus)
                                    editor.load();
                            }

                            target: Notes
                        }
                        onTextChanged: {
                            if (activeFocus && noteId !== "")
                                Notes.setText(noteId, text);
                        }
                        wrapMode: TextEdit.Wrap
                        placeholderText: "Write something…"
                        placeholderTextColor: Appearance.mutedColor
                        color: Appearance.fgColor
                        selectionColor: Appearance.accentColor
                        selectedTextColor: Appearance.accentContrastColor
                        font.family: Appearance.fontFamily
                        font.pixelSize: 15
                        leftPadding: 16
                        rightPadding: 16
                        topPadding: 14
                        bottomPadding: 14
                        background: null
                    }
                }

                // the note as Markdown
                ScrollView {
                    id: viewer

                    anchors.fill: parent
                    anchors.margins: 6
                    visible: root.current !== null && root.mode === "view"
                    contentWidth: availableWidth

                    Text {
                        width: viewer.availableWidth
                        padding: 16
                        text: root.noteText.trim() === "" ? "Nothing to show yet" : root.noteText
                        textFormat: root.noteText.trim() === "" ? Text.PlainText : Text.MarkdownText
                        wrapMode: Text.Wrap
                        color: root.noteText.trim() === "" ? Appearance.mutedColor : Appearance.fgColor
                        linkColor: Appearance.accentColor
                        font.family: Appearance.fontFamily
                        font.pixelSize: 15
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.current === null
                    text: "Press + to write a note"
                    color: Appearance.mutedColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    visible: root.current !== null
                    text: Notes.status !== "" ? Notes.status : root.words + (root.words === 1 ? " word" : " words") + "  ·  " + root.noteText.length + " characters" + (root.notePath !== "" ? "  ·  " + Notes.baseName(root.notePath) : "")
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: Appearance.mutedColor
                }

            }
        }
    }
}
