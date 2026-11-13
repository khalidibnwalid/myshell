import "../../services/"
import QtQuick
import Quickshell

Scope {
    id: root

    property bool shouldShowOsd: false

    function show() {
        // ignore the initial value arriving from PipeWire at startup
        if (startup.running)
            return;
        root.shouldShowOsd = true;
        hideTimer.restart();
    }

    Audio {
        id: audio

        onVolumeChanged: root.show()
        onMuteChanged: root.show()
    }

    Timer {
        id: startup

        interval: 1500
        running: true
    }

    Timer {
        id: hideTimer

        interval: 1200
        onTriggered: root.shouldShowOsd = false
    }

    Osd {
        shown: root.shouldShowOsd
        value: audio.mute ? 0 : audio.volume
        icon: audio.mute || audio.volume === 0 ? "volume_off" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
    }
}
