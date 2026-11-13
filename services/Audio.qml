import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource
    readonly property var outputDevices: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && node.isSink)
    readonly property var inputDevices: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && !node.isSink)
    // Explicitly handle null/undefined states to prevent NaN at startup
    // QML bindings are reactive, so these will update once Pipewire connects.
    property real volume: defaultSink && defaultSink.audio ? defaultSink.audio.volume : 0
    property bool mute: defaultSink && defaultSink.audio ? defaultSink.audio.muted : false

    function setVolume(newVolume) {
        if (defaultSink && defaultSink.audio)
            defaultSink.audio.volume = newVolume;

    }

    function setMute(muted) {
        if (defaultSink && defaultSink.audio)
            defaultSink.audio.muted = muted;

    }

    function setOutput(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setInput(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

}
