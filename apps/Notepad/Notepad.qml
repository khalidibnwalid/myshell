import "../../components"
import "../../config"
import "../../services/"
import "views"
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

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

    // brings the window to the workspace being looked at and focuses it: a file opened from a
    // file manager on one workspace must not land on (or stay on) another one
    function bringHere() {
        // the workspace is taken now: activating the window could switch to the one it is on
        hereTimer.workspace = Hyprland.focusedWorkspace?.id ?? -1;
        hereTimer.tries = 0;
        hereTimer.restart();
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
            view.focusEditor();
    }

    function openFiles() {
        openDialog.open();
    }

    function focusSearch() {
        sidebar.focusSearch();
    }

    function clearSearch() {
        sidebar.clearSearch();
        query = "";
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
        bringHere();
    }

    // the window is known to Hyprland a moment after it maps, so look a few times
    Timer {
        id: hereTimer

        property int tries: 0
        property int workspace: -1

        interval: 60
        onTriggered: {
            const ws = workspace;
            const t = Hyprland.toplevels.values.find(w => {
                const cls = w.wayland?.appId || w.lastIpcObject?.class || "";
                return w.title === "Notepad" && (cls.endsWith("noctalia-qs") || cls.endsWith("quickshell"));
            });
            if (!t || ws < 0) {
                Hyprland.refreshToplevels();
                if (++tries < 15)
                    restart();
                return;
            }
            const address = "0x" + t.address;
            if (t.workspace?.id !== ws)
                HyprCommand.moveWindowToWorkspace(address, ws);
            HyprCommand.focusWindow(address);
        }
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
            // no requestActivate: Hyprland would switch to the window's workspace first
            root.bringHere();
            Qt.callLater(root.focusEditor);
        }

        target: WindowManager
    }

GlobalShortcut {
    name: "notepad"
    onPressed: WindowManager.notepadVisible = !WindowManager.notepadVisible
}

    NotepadIpc {
        window: root
    }

    NotepadKeys {
        window: root
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

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar

            open: root.sidebarOpen
            panelWidth: root.sidebarWidth
            query: root.query
            onFoldRequested: root.sidebarOpen = false
            onWidthDragged: w => root.sidebarWidth = w
            onQueryEdited: text => root.query = text
            onCreateRequested: {
                Notes.create();
                root.focusEditor();
            }
            onNoteOpened: root.focusEditor()
        }

        // --- the note ---
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            Layout.leftMargin: root.sidebarOpen ? 0 : 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            spacing: 10

            TitleBar {
                sidebarOpen: root.sidebarOpen
                hasNote: root.current !== null
                title: root.current ? Notes.titleOf({
                        "text": root.noteText
                    }) : "Notes"
                mode: root.mode
                pinned: root.notePinned
                onSidebarRequested: root.sidebarOpen = true
                onModeSelected: m => {
                    root.mode = m;
                    Qt.callLater(root.focusEditor);
                }
                onOpenRequested: root.openFiles()
                onSaveRequested: root.saveNote(false)
                onCopyRequested: Quickshell.execDetached(["wl-copy", root.noteText])
                onPinRequested: Notes.togglePin(Notes.currentId)
                onDeleteRequested: {
                    Notes.remove(Notes.currentId);
                    root.focusEditor();
                }
                onCloseRequested: WindowManager.notepadVisible = false
            }

            NoteView {
                id: view

                current: root.current
                noteText: root.noteText
                mode: root.mode
            }

            StatusBar {
                hasNote: root.current !== null
                words: root.words
                characters: root.noteText.length
                path: root.notePath
            }
        }
    }

    ClickAway {
    }
}
