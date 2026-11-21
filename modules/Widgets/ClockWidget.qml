import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick

// The clock widget, straight on the wallpaper. Looks: "stacked" (huge two-colour digits, hours over
// minutes), "digital" (one line, like the lock screen) and "analog". `u` is the size (1 = normal).
Item {
    id: root

    property real u: 1
    property var look: ({})
    readonly property color fg: look.fg ?? Appearance.fgColor
    readonly property color accent: look.accent ?? Appearance.accentColor
    readonly property color muted: Qt.alpha(fg, 0.62)
    property string style: "stacked"
    readonly property date now: Time.date
    readonly property string hours: Config.bar.clock24h ? Time.format("HH") : String(((now.getHours() % 12) || 12)).padStart(2, "0")
    readonly property string minutes: Time.format("mm")
    // space between the digits (hours and minutes), and between the letters and words of the date: 0 is the
    // default look, more is wider, a negative number closer
    readonly property real gap: look.gap ?? 0
    readonly property real digitGap: look.digitGap ?? 0
    readonly property real dateK: look.dateGap ?? 1
    readonly property bool showDate: !(look.hideDate ?? false)
    readonly property string dateText: Time.format("dddd  d MMMM").toUpperCase()

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    Loader {
        id: loader

        sourceComponent: root.style === "analog" ? analog : root.style === "digital" ? digital : stacked
    }

    // 11 / 42: each digit its own colour, the lines tucked into each other
    Component {
        id: stacked

        Item {
            readonly property real size: 190 * root.u

            implicitWidth: Math.max(grid.width, dateLine.implicitWidth) + 12 * root.u
            implicitHeight: grid.height + (root.showDate ? dateLine.implicitHeight + 14 * root.u : 8 * root.u)

            Grid {
                id: grid

                columns: 2
                columnSpacing: -size * 0.04 + root.digitGap * size * 0.07
                rowSpacing: -size * 0.3 + root.gap * size * 0.14

                Repeater {
                    model: [
                        {
                            "ch": root.hours.charAt(0),
                            "tint": 0
                        },
                        {
                            "ch": root.hours.charAt(1),
                            "tint": 1
                        },
                        {
                            "ch": root.minutes.charAt(0),
                            "tint": 1
                        },
                        {
                            "ch": root.minutes.charAt(1),
                            "tint": 0
                        }
                    ]

                    ShadowText {
                        look: root.look
                        required property var modelData

                        text: modelData.ch
                        pixelSize: size
                        shadow: 5 * root.u
                        color: modelData.tint ? root.accent : root.fg
                    }
                }
            }

            ShadowText {
                look: root.look
                id: dateLine

                visible: root.showDate
                anchors.top: grid.bottom
                anchors.topMargin: -size * 0.04
                anchors.left: grid.left
                anchors.leftMargin: 4 * root.u
                text: root.dateText
                pixelSize: 24 * root.u
                weight: Font.Medium
                letterSpacing: 5 * root.u * root.dateK
                wordSpacing: (root.dateK - 1) * 12 * root.u
                shadow: 2 * root.u
                color: root.fg
            }
        }
    }

    // 10 56, the hours in the text colour and the minutes in the accent, with the date over them
    Component {
        id: digital

        Item {
            implicitWidth: Math.max(row.width, dateRow.implicitWidth)
            implicitHeight: (root.showDate ? dateRow.implicitHeight : 0) + row.height

            ShadowText {
                look: root.look
                id: dateRow

                visible: root.showDate
                text: root.dateText
                pixelSize: 17 * root.u
                weight: Font.DemiBold
                letterSpacing: 4 * root.u * root.dateK
                wordSpacing: (root.dateK - 1) * 12 * root.u
                shadow: 2 * root.u
                color: root.muted
            }

            Row {
                id: row

                anchors.top: parent.top
                anchors.topMargin: root.showDate ? dateRow.implicitHeight : 0
                spacing: 16 * root.u

                ShadowText {
                    look: root.look
                    text: root.hours
                    pixelSize: 132 * root.u
                    weight: Font.Bold
                    letterSpacing: (-3 + root.digitGap * 8) * root.u
                    shadow: 4 * root.u
                    color: root.fg
                }

                ShadowText {
                    look: root.look
                    text: root.minutes
                    pixelSize: 132 * root.u
                    weight: Font.Bold
                    letterSpacing: (-3 + root.digitGap * 8) * root.u
                    shadow: 4 * root.u
                    color: root.accent
                }
            }
        }
    }

    // a bare face: ticks, three hands, the date under it
    Component {
        id: analog

        Item {
            implicitWidth: 240 * root.u
            implicitHeight: 240 * root.u + (root.showDate ? dateRow2.implicitHeight + 6 * root.u : 0)

            Item {
                id: face

                width: 240 * root.u
                height: width

                Repeater {
                    model: 60

                    Rectangle {
                        required property int index
                        readonly property bool big: index % 5 === 0

                        width: big ? 4 * root.u : 2 * root.u
                        height: big ? 16 * root.u : 7 * root.u
                        radius: width / 2
                        color: big ? root.accent : Qt.alpha(root.fg, 0.6)
                        x: face.width / 2 - width / 2
                        antialiasing: true
                        transform: Rotation {
                            origin.x: width / 2
                            origin.y: face.height / 2
                            angle: index * 6
                        }
                    }
                }

                Repeater {
                    model: [
                        {
                            "len": 0.5,
                            "w": 10,
                            "angle": (root.now.getHours() % 12 + root.now.getMinutes() / 60) * 30,
                            "tint": 0
                        },
                        {
                            "len": 0.74,
                            "w": 7,
                            "angle": (root.now.getMinutes() + root.now.getSeconds() / 60) * 6,
                            "tint": 0
                        },
                        {
                            "len": 0.82,
                            "w": 3,
                            "angle": root.now.getSeconds() * 6,
                            "tint": 1
                        }
                    ]

                    Item {
                        required property var modelData

                        width: modelData.w * root.u
                        height: face.height / 2 * modelData.len
                        x: face.width / 2 - width / 2
                        y: face.height / 2 - height
                        transform: Rotation {
                            origin.x: width / 2
                            origin.y: height
                            angle: modelData.angle
                        }

                        Rectangle {
                            x: 2 * root.u
                            y: 3 * root.u
                            width: parent.width
                            height: parent.height
                            radius: width / 2
                            color: "#59000000"
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: modelData.tint ? root.accent : root.fg
                            antialiasing: true
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 18 * root.u
                    height: width
                    radius: width / 2
                    color: root.accent
                }
            }

            ShadowText {
                look: root.look
                id: dateRow2

                visible: root.showDate
                anchors.top: face.bottom
                anchors.topMargin: 6 * root.u
                anchors.horizontalCenter: face.horizontalCenter
                text: root.dateText
                pixelSize: 15 * root.u
                weight: Font.DemiBold
                letterSpacing: 4 * root.u * root.dateK
                wordSpacing: (root.dateK - 1) * 12 * root.u
                shadow: 2 * root.u
                color: root.fg
            }
        }
    }
}
