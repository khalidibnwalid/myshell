import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

SettingsPage {
    id: page

    readonly property var sink: audio.defaultSink
    readonly property var source: audio.defaultSource
    // applications that are playing or recording right now
    readonly property var streams: Pipewire.nodes.values.filter(node => node.audio && node.isStream)

    function deviceName(node) {
        return node.description || node.nickname || node.name || "Audio device";
    }

    function devices(nodes) {
        return nodes.map(node => ({
            "label": deviceName(node),
            "value": node
        }));
    }

    function streamName(node) {
        return node.properties["application.name"] || node.description || node.name || "Application";
    }

    title: "Sound"
    subtitle: sink ? deviceName(sink) : "No output device"

    Audio {
        id: audio
    }

    SettingGroup {
        title: "Output"

        SettingRow {
            icon: "speaker"
            title: "Output device"
            description: "Where sound plays"

            Dropdown {
                model: page.devices(audio.outputDevices)
                value: page.sink
                placeholder: "No output"
                popupWidth: 340
                onSelected: node => audio.setOutput(node)
            }
        }

        SettingRow {
            title: "Volume"
            description: audio.mute ? "Muted" : Math.round(audio.volume * 100) + "%"

            IconButton {
                toggled: audio.mute
                icon: audio.mute ? "volume_off" : "volume_up"
                onClicked: audio.setMute(!audio.mute)
            }

            PillSlider {
                implicitWidth: 260
                implicitHeight: 36
                icon: audio.mute ? "volume_off" : "volume_up"
                value: Math.min(1, audio.volume)
                onDragged: v => audio.setVolume(v)
            }
        }
    }

    SettingGroup {
        title: "Input"

        SettingRow {
            icon: "mic"
            title: "Microphone"
            description: "What records your voice"

            Dropdown {
                model: page.devices(audio.inputDevices)
                value: page.source
                placeholder: "No microphone"
                popupWidth: 340
                onSelected: node => audio.setInput(node)
            }
        }

        SettingRow {
            visible: !!page.source?.audio
            title: "Input level"
            description: page.source?.audio?.muted ? "Muted" : Math.round((page.source?.audio?.volume ?? 0) * 100) + "%"

            IconButton {
                toggled: page.source?.audio?.muted ?? false
                icon: page.source?.audio?.muted ? "mic_off" : "mic"
                onClicked: page.source.audio.muted = !page.source.audio.muted
            }

            PillSlider {
                implicitWidth: 260
                implicitHeight: 36
                icon: "mic"
                value: Math.min(1, page.source?.audio?.volume ?? 0)
                onDragged: v => page.source.audio.volume = v
            }
        }
    }

    SettingGroup {
        title: "Applications"

        Repeater {
            model: page.streams

            delegate: SettingRow {
                id: stream

                required property var modelData

                icon: modelData.isSink ? "graphic_eq" : "mic"
                title: page.streamName(modelData)
                description: (modelData.properties["media.name"] || (modelData.isSink ? "Playing" : "Recording")) + "  ·  " + (modelData.audio.muted ? "Muted" : Math.round(modelData.audio.volume * 100) + "%")

                IconButton {
                    toggled: stream.modelData.audio.muted
                    icon: stream.modelData.audio.muted ? "volume_off" : "volume_up"
                    onClicked: stream.modelData.audio.muted = !stream.modelData.audio.muted
                }

                PillSlider {
                    implicitWidth: 220
                    implicitHeight: 36
                    icon: stream.modelData.isSink ? "volume_up" : "mic"
                    value: Math.min(1, stream.modelData.audio.volume)
                    onDragged: v => stream.modelData.audio.volume = v
                }
            }
        }

        SettingRow {
            visible: page.streams.length === 0
            title: "Nothing is playing"
            description: "Applications show up here while they play or record sound"
        }
    }
}
