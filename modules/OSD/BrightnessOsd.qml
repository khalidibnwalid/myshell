import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Scope {
    id: root

    property bool shouldShowOsd: false

    Backlight {
        id: backlight

        // Direct signal handler is most reliable
        onChanged: {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer

        interval: 1500
        onTriggered: root.shouldShowOsd = false
    }

    PanelWindow {
        anchors.right: true
        margins.right: 110
        exclusiveZone: 0
        implicitWidth: 64
        implicitHeight: 240
        color: "transparent"
        visible: root.shouldShowOsd

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            // background
            Rectangle {
                anchors.fill: parent
                color: Appearance.bgColor
                radius: 20
                opacity: 0.8
                border.color: Appearance.accentColor
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
                    value: backlight.percentage
                    onDragged: backlight.setBrightness(value)
                    icon: "light_mode"
                    borderMargin: 4
                }

            }

        }

        mask: Region {
        }

    }

}
