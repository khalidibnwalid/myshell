import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick

// The calendar widget, straight on the wallpaper: the day in big letters, the month under it.
// `u` is the size.
Item {
    id: root

    property real u: 1
    property var look: ({})
    readonly property color fg: look.fg ?? Appearance.fgColor
    readonly property color accent: look.accent ?? Appearance.accentColor
    readonly property color muted: Qt.alpha(fg, 0.62)
    property string style: ""
    readonly property bool showDate: !(look.hideDate ?? false)
    readonly property date today: Time.date
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property var dayLetters: ["S", "M", "T", "W", "T", "F", "S"]
    // the weeks of this month: 7 cells each, 0 for a day of another month
    readonly property var weeks: {
        const y = today.getFullYear();
        const m = today.getMonth();
        const lead = (new Date(y, m, 1).getDay() - firstDay + 7) % 7;
        const days = new Date(y, m + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < lead; i++)
            cells.push(0);
        for (let d = 1; d <= days; d++)
            cells.push(d);
        while (cells.length % 7 !== 0)
            cells.push(0);
        return cells;
    }

    implicitWidth: col.implicitWidth + 8 * u
    implicitHeight: col.implicitHeight + 8 * u

    Column {
        id: col

        spacing: 8 * root.u

        Row {
            visible: root.showDate
            spacing: 18 * root.u

            ShadowText {
                look: root.look
                text: String(root.today.getDate())
                pixelSize: 110 * root.u
                shadow: 4 * root.u
                color: root.accent
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                ShadowText {
                    look: root.look
                    text: Time.format("dddd").toUpperCase()
                    pixelSize: 22 * root.u
                    weight: Font.DemiBold
                    letterSpacing: 4 * root.u
                    shadow: 2 * root.u
                    color: root.fg
                }

                ShadowText {
                    look: root.look
                    text: Time.format("MMMM yyyy").toUpperCase()
                    pixelSize: 15 * root.u
                    weight: Font.Medium
                    letterSpacing: 3 * root.u
                    shadow: 2 * root.u
                    color: root.muted
                }
            }
        }

        Grid {
            columns: 7
            columnSpacing: 0
            rowSpacing: 2 * root.u

            Repeater {
                model: 7

                Item {
                    required property int index

                    width: 38 * root.u
                    height: 26 * root.u

                    ShadowText {
                        look: root.look
                        anchors.centerIn: parent
                        text: root.dayLetters[(index + root.firstDay) % 7]
                        pixelSize: 13 * root.u
                        weight: Font.DemiBold
                        shadow: 1.5 * root.u
                        color: root.muted
                    }
                }
            }

            Repeater {
                model: root.weeks

                Item {
                    required property int modelData
                    readonly property bool isToday: modelData === root.today.getDate()

                    width: 38 * root.u
                    height: 32 * root.u

                    Rectangle {
                        visible: parent.isToday
                        anchors.centerIn: parent
                        width: 30 * root.u
                        height: width
                        radius: width / 2
                        color: root.accent
                    }

                    ShadowText {
                        look: root.look
                        anchors.centerIn: parent
                        visible: parent.modelData > 0
                        text: String(parent.modelData)
                        pixelSize: 16 * root.u
                        weight: parent.isToday ? Font.Bold : Font.Medium
                        shadow: parent.isToday ? 0 : 1.5 * root.u
                        color: parent.isToday ? Appearance.accentContrastColor : root.fg
                    }
                }
            }
        }
    }
}
