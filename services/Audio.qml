import QtQuick
import Quickshell.Services.Pipewire
import Quickshell

Scope {
    id: root

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property var defaultSink: Pipewire.defaultAudioSink
    property real volume: defaultSink.audio.volume
    property bool mute: defaultSink.audio.mute

    Connections {
        target: defaultSink.audio
        function onVolumeChanged() {
            root.volume = defaultSink.audio.volume;
        }

        function onMuteChanged() {
            root.mute = defaultSink.audio.mute;
        }
    }

    function setVolume(newVolume) {
        defaultSink.audio.volume = newVolume;
    }
}
