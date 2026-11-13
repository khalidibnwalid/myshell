import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import Quickshell

PanelWindow {
    id: root

    property var barWindow
    property real anchorY: 0
    property real anchorHeight: 24
    property bool open: false
    readonly property bool barRight: Config.layout.barPosition === "right"
    readonly property real screenHeight: screen ? screen.height : 800

    function show(y, iconHeight) {
        anchorY = y;
        anchorHeight = iconHeight;
        open = true;
        closeTimer.stop();
    }

    function hideLater() {
        closeTimer.restart();
    }

    screen: barWindow ? barWindow.screen : null
    visible: open || closeTimer.running
    anchors {
        top: true
        right: barRight
        left: !barRight
    }
    margins {
        top: Math.max(8, Math.min(anchorY + anchorHeight / 2 - implicitHeight / 2, screenHeight - implicitHeight - 8))
        right: 5
        left: 5
    }
    exclusiveZone: 0
    implicitWidth: 226
    implicitHeight: 58
    color: "transparent"

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.open = false
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 29
        color: Appearance.panelColor
        border.width: 1
        border.color: Appearance.hairlineColor

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    closeTimer.stop();
                else if (root.open)
                    root.hideLater();
            }
        }

        Audio {
            id: audio
        }

        PillSlider {
            anchors.fill: parent
            anchors.margins: 5
            value: audio.mute ? 0 : audio.volume
            icon: audio.mute || audio.volume === 0 ? "volume_off" : (audio.volume < 0.5 ? "volume_down" : "volume_up")
            Accessible.name: "Volume"
            onDragged: value => {
                audio.setVolume(value);
                if (audio.mute && value > 0)
                    audio.setMute(false);
            }
        }
    }
}
