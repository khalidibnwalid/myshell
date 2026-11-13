import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell

// Small on-screen message for a state change (Caps Lock, keyboard layout, charger…):
// an icon and a short line in a pill near the bottom of the screen. Click-through.
PanelWindow {
    id: root

    property string icon
    property string title
    property string detail
    property bool shown: false
    // accent icon for "on" states, muted for "off"
    property bool highlighted: true

    anchors.bottom: true
    margins.bottom: 110
    exclusiveZone: 0
    implicitWidth: pill.implicitWidth
    implicitHeight: 68
    color: "transparent"
    visible: shown || keepAlive.running
    onShownChanged: {
        if (!shown)
            keepAlive.restart();
    }

    // stay mapped while the pill fades out
    Timer {
        id: keepAlive

        interval: Appearance.animNormal
    }

    Rectangle {
        id: pill

        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 56
        width: implicitWidth
        height: parent.height
        radius: height / 2
        color: Appearance.panelColor
        border.width: 1
        border.color: Appearance.hairlineColor
        opacity: root.shown ? 1 : 0

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 14

            MaterialSymbol {
                icon: root.icon
                fill: root.highlighted ? 1 : 0
                font.pixelSize: 30
                color: root.highlighted ? Appearance.accentColor : Appearance.mutedColor
            }

            StyledText {
                text: root.title
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            StyledText {
                visible: root.detail !== ""
                text: root.detail
                color: Appearance.mutedColor
                font.pixelSize: 16
            }
        }

        transform: Translate {
            y: root.shown ? 0 : 12

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeOut
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animFast
            }
        }
    }

    // An empty click mask prevents the window from blocking mouse events.
    mask: Region {
    }
}
