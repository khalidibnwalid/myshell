import "../../components/"
import "../../config/"
import QtQuick
import Quickshell

// Vertical on-screen level pill (volume, brightness). Click-through.
// It grows out from the bar's side with a soft overshoot and shrinks back into it; while it shows,
// each change gives it a small bump, the fill glides to the new level and the number counts to it.
PanelWindow {
    id: root

    property real value: 0
    property string icon
    property bool shown: false
    property int offset: 12
    readonly property bool barRight: Config.panelRight
    readonly property real level: Math.max(0, Math.min(1, value))
    // room around the pill, so the overshoot of the entrance is not clipped by the window
    readonly property int room: 6

    anchors.right: barRight
    anchors.left: !barRight
    margins.right: offset - room
    margins.left: offset - room
    exclusiveZone: 0
    implicitWidth: 60 + room * 2
    implicitHeight: 250 + room * 2
    color: "transparent"
    // mapped from the moment it shows until it has gone: a binding on keepAlive.running dropped to
    // false for an instant before the timer restarted, which unmapped the window and made it flicker
    property bool held: false

    visible: shown || held
    onShownChanged: {
        if (shown) {
            keepAlive.stop();
            held = true;
        } else {
            keepAlive.restart();
        }
    }
    // a change while the pill is up: a small bump, so the step is felt
    onLevelChanged: {
        if (shown && pill.opacity > 0.9)
            bump.restart();
    }
    onIconChanged: {
        if (shown)
            iconPop.restart();
    }

    // stay mapped while the pill shrinks away
    Timer {
        id: keepAlive

        interval: Appearance.animNormal
        onTriggered: root.held = false
    }

    Rectangle {
        id: pill

        // the shown number follows the level smoothly instead of jumping
        property real shownLevel: root.level
        // grows from the bar's side
        transformOrigin: root.barRight ? Item.Right : Item.Left

        anchors.fill: parent
        anchors.margins: root.room
        radius: width / 2
        color: Appearance.panelColor
        border.width: 1
        border.color: Appearance.hairlineColor
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.9
        // drawn as one picture while it scales, so the text and edges move without jitter
        layer.enabled: true
        layer.smooth: true

        Behavior on shownLevel {
            NumberAnimation {
                duration: Appearance.animNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeStandard
            }
        }

        // in: quick with a slight overshoot; out: quicker, without one
        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? Appearance.animNormal : Appearance.animFast
                easing.type: root.shown ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 0.8
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeFade
            }
        }

        // the bump on a change: a little wider for a moment
        transform: Scale {
            id: bumpScale

            origin.x: pill.width / 2
            origin.y: pill.height / 2
            xScale: 1
            yScale: 1
        }

        SequentialAnimation {
            id: bump

            NumberAnimation {
                target: bumpScale
                properties: "xScale"
                to: 1.08
                duration: 70
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: bumpScale
                properties: "xScale"
                to: 1
                duration: Appearance.animNormal
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }

        Rectangle {
            id: track

            anchors.fill: parent
            anchors.margins: 7
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
                        duration: Appearance.animNormal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.easeStandard
                    }
                }
            }

            StyledText {
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(pill.shownLevel * 100)
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
                color: root.level > 0.86 ? Appearance.accentContrastColor : Appearance.mutedColor

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animFast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.easeFade
                    }
                }
            }

            MaterialSymbol {
                id: iconItem

                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.icon
                font.pixelSize: 24
                color: Appearance.accentContrastColor

                // a pop when the icon changes (muted, unmuted, a new level band)
                SequentialAnimation {
                    id: iconPop

                    NumberAnimation {
                        target: iconItem
                        property: "scale"
                        to: 1.3
                        duration: 90
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        target: iconItem
                        property: "scale"
                        to: 1
                        duration: Appearance.animNormal
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.2
                    }
                }
            }
        }
    }

    // An empty click mask prevents the window from blocking mouse events.
    mask: Region {
    }
}
