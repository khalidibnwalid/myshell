import "../../services/"
import QtQuick
import Quickshell

// Level pill for the microphone: shows when its volume or mute state changes.
Scope {
    id: root

    property bool shouldShowOsd: false
    readonly property var mic: audio.defaultSource?.audio ?? null

    function show() {
        // ignore the initial values arriving from PipeWire at startup
        if (startup.running)
            return;
        root.shouldShowOsd = true;
        hideTimer.restart();
    }

    Audio {
        id: audio
    }

    Connections {
        function onVolumeChanged() {
            root.show();
        }

        function onMutedChanged() {
            root.show();
        }

        target: root.mic
    }

    Timer {
        id: startup

        interval: 1500
        running: true
    }

    // switching to another microphone is not a level change
    Connections {
        function onDefaultSourceChanged() {
            startup.restart();
        }

        target: audio
    }

    Timer {
        id: hideTimer

        interval: 1200
        onTriggered: root.shouldShowOsd = false
    }

    Osd {
        shown: root.shouldShowOsd
        value: !root.mic || root.mic.muted ? 0 : root.mic.volume
        icon: !root.mic || root.mic.muted ? "mic_off" : "mic"
        offset: 152
    }
}
