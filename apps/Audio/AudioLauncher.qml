import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The part of Audio that lives in the main shell: its global shortcuts and the `audio` IPC target.
// They pass on to the Audio program (scripts/ctl.sh), which is started when one needs it.
// bind = $mainMod, M, global, quickshell:audio
Scope {
    id: root

    function run(args) {
        Quickshell.execDetached([Quickshell.shellDir + "/apps/Audio/scripts/ctl.sh"].concat(args));
    }

    GlobalShortcut {
        name: "audio"
        onPressed: root.run(["toggle"])
    }

    GlobalShortcut {
        name: "audioPlayPause"
        onPressed: root.run(["playpause"])
    }

    GlobalShortcut {
        name: "audioNext"
        onPressed: root.run(["next"])
    }

    GlobalShortcut {
        name: "audioPrevious"
        onPressed: root.run(["previous"])
    }

    // qs ipc call audio toggle | open | close | playpause | play | pause | stop | next | previous
    //                        | openFile <path> | enqueue <path> | volume <0-100>
    IpcHandler {
        function toggle(): void {
            root.run(["toggle"]);
        }

        function open(): void {
            root.run(["open"]);
        }

        function close(): void {
            root.run(["close"]);
        }

        function quit(): void {
            root.run(["quit"]);
        }

        function playpause(): void {
            root.run(["playpause"]);
        }

        function play(): void {
            root.run(["play"]);
        }

        function pause(): void {
            root.run(["pause"]);
        }

        function stop(): void {
            root.run(["stop"]);
        }

        function next(): void {
            root.run(["next"]);
        }

        function previous(): void {
            root.run(["previous"]);
        }

        function openFile(path: string): void {
            root.run(["openFile", path]);
        }

        function enqueue(path: string): void {
            root.run(["enqueue", path]);
        }

        function volume(percent: int): void {
            root.run(["volume", String(percent)]);
        }

        target: "audio"
    }
}
