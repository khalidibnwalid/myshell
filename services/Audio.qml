import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property var defaultSink: Pipewire.defaultAudioSink
    // Explicitly handle null/undefined states to prevent NaN at startup
    // QML bindings are reactive, so these will update once Pipewire connects.
    property real volume: defaultSink && defaultSink.audio ? defaultSink.audio.volume : 0
    property bool mute: defaultSink && defaultSink.audio ? defaultSink.audio.mute : false

    function setVolume(newVolume) {
        if (defaultSink && defaultSink.audio)
            defaultSink.audio.volume = newVolume;

    }

    function setMute(muted) {
        if (defaultSink && defaultSink.audio)
            defaultSink.audio.mute = muted;

    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

}
