import "../../components/"
import "../../config/"
import QtQuick
import Quickshell

// Vertical on-screen level pill (volume, brightness). Click-through.
PanelWindow {
    id: root

    property real value: 0
    property string icon
    property bool shown: false
    property int offset: 12
    readonly property bool barRight: Config.panelRight
    readonly property real level: Math.max(0, Math.min(1, value))

    anchors.right: barRight
    anchors.left: !barRight
    margins.right: offset
    margins.left: offset
    exclusiveZone: 0
    implicitWidth: 52
    implicitHeight: 216
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
        anchors.fill: parent
        radius: width / 2
        color: Appearance.panelColor
        border.width: 1
        border.color: Appearance.hairlineColor
        opacity: root.shown ? 1 : 0

        Rectangle {
            id: track

            anchors.fill: parent
            anchors.margins: 6
            radius: width / 2
            color: Appearance.surfaceColor
            clip: true

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(width, parent.height * root.level)
                radius: width / 2
                color: Appearance.accentColor

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            StyledText {
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(root.level * 100)
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: root.level > 0.86 ? Appearance.onAccentColor : Appearance.mutedColor
            }

            MaterialSymbol {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.icon
                font.pixelSize: 20
                color: Appearance.onAccentColor
            }
        }

        transform: Translate {
            x: root.shown ? 0 : (root.barRight ? 14 : -14)

            Behavior on x {
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
