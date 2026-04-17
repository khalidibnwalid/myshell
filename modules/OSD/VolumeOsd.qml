import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// credits to the official example
Scope {
    id: root

    property bool shouldShowOsd: false

    Audio {
        id: audio
    }

    Connections {
        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }

        target: audio
    }

    Timer {
        id: hideTimer

        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    // The OSD window will be created and destroyed based on shouldShowOsd.
    // PanelWindow.visible could be set instead of using a loader, but using
    // a loader will reduce the memory overhead when the window isn't open.
    LazyLoader {
        active: root.shouldShowOsd

        PanelWindow {
            anchors.right: true
            margins.right: 32
            exclusiveZone: 0
            implicitWidth: 64
            implicitHeight: 240
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                // background
                Rectangle {
                    anchors.fill: parent
                    color: Appearance.bgColor
                    radius: 20
                    opacity: 0.7
                    border.color: Appearance.borderColor
                    border.width: 1
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 4
                    }

                    VolumeSlider {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        value: audio.volume
                        onDragged: audio.setVolume(value)
                        icon: audio.volume === 0 ? "volume_mute" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
                        borderMargin: 4
                    }

                }

            }

            // An empty click mask prevents the window from blocking mouse events.
            mask: Region {
            }

        }

    }

}
