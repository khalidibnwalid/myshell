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

    // Apps recording from a microphone right now: capture streams, leaving out the ones that only
    // listen to what plays (the bar's and the desktop's sound waves record the speakers' monitor)
    readonly property var micStreams: Pipewire.nodes.values.filter(node => node.audio && node.isStream && node.type === PwNodeType.AudioInStream && node.properties["stream.capture.sink"] !== "true")
    readonly property bool micInUse: micStreams.length > 0
    readonly property bool micMuted: defaultSource && defaultSource.audio ? defaultSource.audio.muted : false
    readonly property string micUsers: {
        const names = [];
        for (const n of micStreams) {
            const name = n.properties["application.name"] || n.name;
            if (name && names.indexOf(name) < 0)
                names.push(name);
        }
        return names.join(", ");
    }

    function toggleMicMute() {
        if (defaultSource && defaultSource.audio)
            defaultSource.audio.muted = !defaultSource.audio.muted;
    }

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
