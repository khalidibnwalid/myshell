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

    // room around the pill, so the overshoot of the entrance is not clipped by the window
    readonly property int room: 8

    anchors.bottom: true
    margins.bottom: 110 - room
    exclusiveZone: 0
    implicitWidth: pill.implicitWidth + room * 2
    implicitHeight: 68 + room * 2
    color: "transparent"
    // mapped from the moment it shows until it has gone: a binding on keepAlive.running dropped to
    // false for an instant before the timer restarted, which unmapped the window and made it flicker
    property bool held: false

    visible: shown || held
    onShownChanged: {
        if (shown) {
            keepAlive.stop();
            held = true;
            iconPop.restart();
        } else {
            keepAlive.restart();
        }
    }
    // a new message while one shows (Caps Lock on, then off): the icon pops again
    onTitleChanged: {
        if (shown)
            iconPop.restart();
    }

    // stay mapped while the pill fades out
    Timer {
        id: keepAlive

        interval: Appearance.animNormal
        onTriggered: root.held = false
    }

    Rectangle {
        id: pill

        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 56
        width: implicitWidth
        height: parent.height - root.room * 2
        radius: height / 2
        color: Appearance.panelColor
        border.width: 1
        border.color: Appearance.hairlineColor
        opacity: root.shown ? 1 : 0
        // rises and grows into place with a soft overshoot; sinks and shrinks away
        scale: root.shown ? 1 : 0.9
        // drawn as one picture while it moves, so the text and edges move without jitter
        layer.enabled: true
        layer.smooth: true

        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? Appearance.animNormal : Appearance.animFast
                easing.type: root.shown ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 0.8
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Appearance.animNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeStandard
            }
        }

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 14

            MaterialSymbol {
                id: iconItem

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
                    duration: root.shown ? Appearance.animNormal : Appearance.animFast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeStandard
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeFade
            }
        }

        // the icon pops in a moment after the pill, and again for a new message
        SequentialAnimation {
            id: iconPop

            PropertyAction {
                target: iconItem
                property: "scale"
                value: 0.6
            }

            PauseAnimation {
                duration: 60
            }

            NumberAnimation {
                target: iconItem
                property: "scale"
                to: 1
                duration: Appearance.animSlow
                easing.type: Easing.OutBack
                easing.overshoot: 2.4
            }
        }
    }

    // An empty click mask prevents the window from blocking mouse events.
    mask: Region {
    }
}
