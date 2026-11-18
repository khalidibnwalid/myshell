import QtQuick

// The keys of the Notepad window.
Item {
    id: root

    property var window: null

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: {
            Notes.create();
            Qt.callLater(window.focusEditor);
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+V"
        onActivated: {
            window.mode = window.mode === "edit" ? "view" : "edit";
            Qt.callLater(window.focusEditor);
        }
    }

    Shortcut {
        sequence: "Ctrl+S"
        onActivated: window.saveNote(false)
    }

    Shortcut {
        sequence: "Ctrl+Shift+S"
        onActivated: window.saveNote(true)
    }

    Shortcut {
        sequence: "Ctrl+O"
        onActivated: window.openFiles()
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: window.sidebarOpen = !window.sidebarOpen
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: window.sidebarOpen
        onActivated: search.focusInput()
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.query !== ""
        onActivated: window.clearSearch()
    }
}
