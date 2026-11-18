import "../../services/"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The Paint app: its shortcut and IPC target, and its window, which exists only while it is open. The
// document lives in PaintDoc and the engine process, so closing the window keeps it.
// bind = $mainMod, P, global, quickshell:paint
Scope {
    id: root

    function shutdown() {
        PaintDoc.send({
            "op": "quit"
        });
    }

    GlobalShortcut {
        name: "paint"
        onPressed: Apps.toggle("paint")
    }

    // qs ipc call paint toggle | open | close | openFile /path/to/image.png | create 800 600
    IpcHandler {
        function toggle(): void {
            Apps.toggle("paint");
        }

        function open(): void {
            Apps.open("paint");
        }

        function close(): void {
            Apps.close("paint");
        }

        function openFile(path: string): void {
            Apps.open("paint");
            PaintDoc.start();
            PaintDoc.openFile(path);
        }

        function create(width: int, height: int): void {
            Apps.open("paint");
            PaintDoc.newDoc(Math.max(1, width), Math.max(1, height), "white");
        }

        target: "paint"
    }

    LazyLoader {
        active: Apps.isOpen("paint")

        Paint {
        }
    }
}
