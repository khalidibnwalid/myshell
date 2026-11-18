import QtQuick
import Quickshell.Io

// The `audio` IPC target of the Audio program (the shell's own `audio` target passes commands on to it).
// qs ipc call audio toggle | open | close | playpause | play | pause | next | previous | stop
//                        | openFile <path> | enqueue <path> | volume <0-100> | status
Item {
    id: root

    // the Audio window
    property var window: null

    IpcHandler {
        function toggle(): void {
            if (window.shown)
                window.shown = false;
            else
                window.openWindow();
        }

        function open(): void {
            window.openWindow();
        }

        function close(): void {
            window.shown = false;
        }

        function quit(): void {
            Player.shutdown();
            Qt.quit();
        }

        function playpause(): void {
            Player.toggle();
        }

        function play(): void {
            Player.play();
        }

        function pause(): void {
            Player.pause();
        }

        function stop(): void {
            Player.stop();
        }

        function next(): void {
            Player.next();
        }

        function previous(): void {
            Player.previous();
        }

        function openFile(path: string): void {
            Player.openPaths([path], false);
            window.openWindow();
        }

        function enqueue(path: string): void {
            Player.openPaths([path], true);
        }

        function volume(percent: int): void {
            Player.setVolume(percent / 100);
        }

        function status(): string {
            const t = Player.track;
            if (!t)
                return "Nothing is playing";
            return (Player.playing ? "Playing" : "Paused") + ": " + (t.artist ? t.artist + " - " : "") + t.title + " (" + Library.format(Player.positionMs / 1000) + "/" + Library.format(Player.durationMs / 1000) + ")";
        }

        target: "audio"
    }
}
