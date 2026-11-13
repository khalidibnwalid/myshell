import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import Quickshell

PanelWindow {
    id: root

    property var barWindow
    property real anchorX: 0
    property real anchorY: 0
    property bool open: false
    readonly property bool barRight: Config.barPosition === "right"
    // beside a side bar at the pointer's height; above or below a top/bottom bar at its x
    readonly property bool horizontal: Config.barHorizontal
    readonly property real screenWidth: screen ? screen.width : 1280
    readonly property real screenHeight: screen ? screen.height : 800

    // point: centre of the volume icon, in bar coordinates
    function show(point) {
        anchorX = point.x;
        anchorY = point.y;
        open = true;
        closeTimer.stop();
    }

    function hideLater() {
        closeTimer.restart();
    }

    screen: barWindow ? barWindow.screen : null
    visible: open || closeTimer.running
    anchors {
        top: Config.barPosition !== "bottom"
        bottom: Config.barPosition === "bottom"
        right: barRight
        left: !barRight
    }
    margins {
        top: horizontal ? 5 : Math.max(8, Math.min(anchorY - implicitHeight / 2, screenHeight - implicitHeight - 8))
        bottom: 5
        right: 5
        left: horizontal ? Math.max(8, Math.min(anchorX - implicitWidth / 2, screenWidth - implicitWidth - 8)) : 5
    }
    exclusiveZone: 0
    implicitWidth: 226
    implicitHeight: 58
    color: "transparent"
    Component.onCompleted: WindowManager.registerBarPopup(root)
    Component.onDestruction: WindowManager.unregisterBarPopup(root)

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
