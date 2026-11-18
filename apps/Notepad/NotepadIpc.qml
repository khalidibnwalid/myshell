import "../../services/"
import QtQuick
import Quickshell.Io

// The `notepad` IPC target.
// qs ipc call notepad toggle | open | close | create
Item {
    id: root

    // the Notepad window
    property var window: null

    IpcHandler {
        function toggle(): void {
            if (WindowManager.notepadVisible)
                WindowManager.notepadVisible = false;
            else
                window.openWindow();
        }

        function open(): void {
            window.openWindow();
        }

        function close(): void {
            WindowManager.notepadVisible = false;
        }

        function openFile(path: string): void {
            window.openWindow();
            Notes.openFile(path);
            Qt.callLater(window.focusEditor);
        }

        function create(): void {
            window.openWindow();
            Notes.create();
            Qt.callLater(window.focusEditor);
        }

        target: "notepad"
    }
}
