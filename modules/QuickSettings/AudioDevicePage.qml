import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var stackView

    implicitHeight: layout.implicitHeight + 32

    Audio {
        id: audio
    }

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12

        PageHeader {
            Layout.fillWidth: true
            title: "Audio devices"
            subtitle: "Choose where sound plays and which microphone to use"
            onBack: stackView.pop()
        }

        StyledText {
            Layout.leftMargin: 6
            text: "OUTPUT"
            color: Appearance.mutedColor
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        ListView {
            id: outputs

            model: audio.outputDevices
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 3 * 59 - 3)
            spacing: 3
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: ListRow {
                required property var modelData
                required property int index

                width: outputs.width
                first: index === 0
                last: index === outputs.count - 1
                active: audio.defaultSink === modelData
                title: modelData.description || modelData.nickname || modelData.name || "Audio output"
                subtitle: active ? "Current output" : ""
                icon: active ? "volume_up" : "speaker"
                trailingIcon: active ? "check" : ""
                onClicked: audio.setOutput(modelData)
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: outputs.count === 0
            text: "No audio outputs found"
            color: Appearance.mutedColor
            font.pixelSize: 13
        }

        StyledText {
            Layout.leftMargin: 6
            Layout.topMargin: 4
            text: "INPUT"
            color: Appearance.mutedColor
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        ListView {
            id: inputs

            model: audio.inputDevices
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 3 * 59 - 3)
            spacing: 3
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: ListRow {
                required property var modelData
                required property int index

                width: inputs.width
                first: index === 0
                last: index === inputs.count - 1
                active: audio.defaultSource === modelData
                title: modelData.description || modelData.nickname || modelData.name || "Audio input"
                subtitle: active ? "Current microphone" : ""
                icon: active ? "mic" : "mic_none"
                trailingIcon: active ? "check" : ""
                onClicked: audio.setInput(modelData)
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: inputs.count === 0
            text: "No microphones found"
            color: Appearance.mutedColor
            font.pixelSize: 13
        }
    }
}
