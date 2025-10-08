import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../components/"
import "../../config/"
import "../../services/"

// credits to the official example
Scope {
    id: root

    Audio {
        id: audio
    }

    Connections {
        target: audio
        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    property bool shouldShowOsd: false

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
            anchors.bottom: true
            margins.bottom: screen.height / 5
            exclusiveZone: 0

            implicitWidth: 400
            implicitHeight: 50
            color: "transparent"

            // An empty click mask prevents the window from blocking mouse events.
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                // background
                Rectangle {
                    anchors.fill: parent
                    color: Appearance.bgColor
                    radius: 17
                    opacity: 0.6
                    border.color: Appearance.borderColor
                    border.width: 1
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 15
                    }

                    MaterialSymbol {
                        icon: audio.volume === 0 ? "volume_mute" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
                        color: Appearance.fgColor
                        font.pixelSize: 32
                        rightPadding: 8
                    }

                    Slider {
                        Layout.fillWidth: true
                        value: audio.volume
                        onDragged: audio.setVolume(value)
                    }
                }
            }
        }
    }
}
