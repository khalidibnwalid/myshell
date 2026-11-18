import QtQuick
import Quickshell

// The part of the Audio program that is always here: the IPC target, the saved queue and the quit timer.
// The window (AudioApp) is only created while it is shown, so closing it gives its memory back.
Scope {
    id: root

    property bool shown: false

    function openWindow() {
        if (windowLoader.item) {
            windowLoader.item.raise();
            windowLoader.item.requestActivate();
        } else {
            shown = true;
        }
    }

    // the library and the saved queue are read from the start of the shell
    Component.onCompleted: {
        Library.load();
        Player.load();
    }

    // a quit or raise asked for over MPRIS
    Connections {
        function onRaiseRequested() {
            root.openWindow();
        }

        function onQuitRequested() {
            root.shown = false;
        }

        target: Player
    }

    // The program is only here while it is used: a minute after the window is closed and the sound is
    // off it quits, with the queue and the place saved.
    Timer {
        interval: 60000
        running: Player.loaded && !root.shown && !Player.playing
        onTriggered: {
            Player.shutdown();
            Qt.quit();
        }
    }

    AudioIpc {
        window: root
    }

    LazyLoader {
        id: windowLoader

        active: root.shown

        component: AudioApp {
            program: root
        }
    }
}
