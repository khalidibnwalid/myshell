import "../config/"
import "../services/"
import QtQuick
import QtQuick.Layouts

// Month calendar: week numbers, a selectable day, jump to any month, wheel to browse.
Rectangle {
    id: root

    property int displayedMonth: new Date().getMonth()
    property int displayedYear: new Date().getFullYear()
    property date selected: new Date()
    // "days" or "months"
    property string mode: "days"
    property bool weekNumbers: true
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property var dayLetters: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    readonly property date today: Time.date

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function monthCells(year, month) {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() - firstDay + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(year, month, 1 - offset + i));
        return out;
    }

    // ISO 8601 week number
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    function dayOfYear(d) {
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 0)) / 86400000);
    }

    function relative(d) {
        const days = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(today.getFullYear(), today.getMonth(), today.getDate())) / 86400000);
        if (days === 0)
            return "Today";
        if (days === 1)
            return "Tomorrow";
        if (days === -1)
            return "Yesterday";
        return days > 0 ? "In " + days + " days" : Math.abs(days) + " days ago";
    }

    function step(delta) {
        const d = new Date(displayedYear, displayedMonth + delta, 1);
        displayedMonth = d.getMonth();
        displayedYear = d.getFullYear();
    }

    function goToday() {
        selected = new Date();
        displayedMonth = selected.getMonth();
        displayedYear = selected.getFullYear();
        mode = "days";
    }

    readonly property var cells: monthCells(displayedYear, displayedMonth)
    readonly property bool away: displayedMonth !== today.getMonth() || displayedYear !== today.getFullYear() || !sameDay(selected, today)

    implicitWidth: 360
    implicitHeight: layout.implicitHeight + 28
    color: Appearance.surfaceColor
    radius: 22
    border.color: Appearance.hairlineColor
    border.width: 1

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 8

        // title (click to jump), today, previous / next
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
                implicitWidth: titleRow.implicitWidth + 20
                implicitHeight: 34
                radius: 17
                color: titleArea.containsMouse || root.mode === "months" ? Appearance.surfaceHighColor : "transparent"

                RowLayout {
                    id: titleRow

                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        text: root.mode === "months" ? root.displayedYear : Qt.formatDate(new Date(root.displayedYear, root.displayedMonth, 1), "MMMM yyyy")
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    MaterialSymbol {
                        icon: "expand_more"
                        font.pixelSize: 18
                        color: Appearance.mutedColor
                        rotation: root.mode === "months" ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Appearance.animFast
                            }
                        }
                    }
                }

                MouseArea {
                    id: titleArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.mode = root.mode === "days" ? "months" : "days"
                }
            }

            Item {
                Layout.fillWidth: true
            }

            PillButton {
                visible: root.away
                implicitHeight: 28
                text: "Today"
                onClicked: root.goToday()
            }

            IconButton {
                size: 32
                iconSize: 20
                icon: "chevron_left"
                onClicked: root.mode === "months" ? root.displayedYear-- : root.step(-1)
            }

            IconButton {
                size: 32
                iconSize: 20
                icon: "chevron_right"
                onClicked: root.mode === "months" ? root.displayedYear++ : root.step(1)
            }
        }

        // --- days: one grid, week number first in every row ---
        GridLayout {
            id: grid

            Layout.fillWidth: true
            visible: root.mode === "days"
            columns: root.weekNumbers ? 8 : 7
            rowSpacing: 0
            columnSpacing: 0

            // weekday letters
            Item {
                visible: root.weekNumbers
                Layout.preferredWidth: 28
                Layout.preferredHeight: 22
            }

            Repeater {
                model: 7

                delegate: StyledText {
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: root.dayLetters[(root.firstDay + index) % 7]
                    color: Appearance.mutedColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    opacity: (root.firstDay + index) % 7 === 0 || (root.firstDay + index) % 7 === 6 ? 0.6 : 1
                }
            }

            Repeater {
                model: 48

                delegate: Item {
                    id: cell

                    required property int index
                    readonly property bool isWeek: index % 8 === 0
                    readonly property var modelData: isWeek ? root.cells[(index / 8) * 7 + 3] : root.cells[Math.floor(index / 8) * 7 + (index % 8) - 1]
                    readonly property bool inMonth: modelData.getMonth() === root.displayedMonth
                    readonly property bool isToday: !isWeek && root.sameDay(modelData, root.today)
                    readonly property bool isSelected: !isWeek && root.sameDay(modelData, root.selected)
                    readonly property bool weekend: modelData.getDay() === 0 || modelData.getDay() === 6

                    visible: !isWeek || root.weekNumbers
                    Layout.fillWidth: !isWeek
                    Layout.preferredWidth: isWeek ? 28 : 1
                    Layout.preferredHeight: 36

                    Rectangle {
                        visible: !cell.isWeek
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        radius: 16
                        color: cell.isToday ? Appearance.accentColor : (cell.isSelected ? Appearance.surfaceHighColor : (cellArea.containsMouse ? Appearance.surfaceColor : "transparent"))
                        border.width: cell.isSelected && !cell.isToday ? 2 : 0
                        border.color: Appearance.accentColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animFast
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: cell.isWeek ? root.isoWeek(cell.modelData) : cell.modelData.getDate()
                        font.pixelSize: cell.isWeek ? 10 : 13
                        font.weight: cell.isToday || cell.isSelected ? Font.Bold : Font.Normal
                        color: cell.isWeek ? Appearance.mutedColor : (cell.isToday ? Appearance.accentContrastColor : (cell.weekend && cell.inMonth ? Appearance.mutedColor : Appearance.fgColor))
                        opacity: cell.isWeek ? 0.6 : (cell.inMonth ? 1 : 0.3)
                    }

                    MouseArea {
                        id: cellArea

                        anchors.fill: parent
                        enabled: !cell.isWeek
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selected = cell.modelData;
                            if (!cell.inMonth) {
                                root.displayedMonth = cell.modelData.getMonth();
                                root.displayedYear = cell.modelData.getFullYear();
                            }
                        }
                    }
                }
            }

            // scrolling over the days browses months
            WheelHandler {
                onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
            }
        }

        // --- months ---
        GridLayout {
            Layout.fillWidth: true
            visible: root.mode === "months"
            columns: 3
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: 12

                delegate: Rectangle {
                    id: month

                    required property int index
                    readonly property bool current: index === root.today.getMonth() && root.displayedYear === root.today.getFullYear()
                    readonly property bool shown: index === root.displayedMonth

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 62
                    radius: 18
                    color: shown ? Appearance.accentColor : (monthArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor)
                    border.width: current && !shown ? 2 : 0
                    border.color: Appearance.accentColor

                    StyledText {
                        anchors.centerIn: parent
                        text: root.monthNames[month.index]
                        font.weight: Font.Medium
                        color: month.shown ? Appearance.accentContrastColor : Appearance.fgColor
                    }

                    MouseArea {
                        id: monthArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.displayedMonth = month.index;
                            root.mode = "days";
                        }
                    }
                }
            }
        }

        // the selected day
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: info.implicitHeight + 20
            radius: 16
            color: Appearance.surfaceColor
            visible: root.mode === "days"

            ColumnLayout {
                id: info

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.selected, "dddd, d MMMM")
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.relative(root.selected) + "  ·  week " + root.isoWeek(root.selected) + "  ·  day " + root.dayOfYear(root.selected)
                    elide: Text.ElideRight
                    color: Appearance.mutedColor
                    font.pixelSize: 12
                }
            }
        }
    }
}
