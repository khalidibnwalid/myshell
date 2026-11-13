import "../../components"
import "../../config"
import "../../services"
import QtQuick
import QtQuick.Layouts

// Clock pill: hours, accent minutes, then weekday and day of month.
// Stacked on a side bar, in one line on a top or bottom bar.
Rectangle {
    id: root

    readonly property bool horizontal: Config.barHorizontal

    implicitWidth: horizontal ? grid.implicitWidth + 28 : 40
    implicitHeight: horizontal ? 36 : grid.implicitHeight + 32
    radius: horizontal ? 18 : 20
    color: clockArea.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor

    // click: quick settings, like the status icons
    MouseArea {
        id: clockArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: WindowManager.toggleQuickSettingsVisible()
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
        }
    }

    GridLayout {
        id: grid

        anchors.centerIn: parent
        columns: root.horizontal ? -1 : 1
        rowSpacing: 0
        columnSpacing: 5

        StyledText {
            Layout.alignment: Qt.AlignCenter
            font.pixelSize: 17
            font.weight: Font.Bold
            // 12-hour clock without am/pm, or 24-hour
            text: Config.bar.clock24h ? Time.format("HH") : Time.format("hh ap").replace(/ ?[ap]m/i, "")
        }

        StyledText {
            Layout.alignment: Qt.AlignCenter
            color: Appearance.accentColor
            font.pixelSize: 17
            font.weight: Font.Bold
            text: Time.format("mm")
        }

        Rectangle {
            Layout.alignment: Qt.AlignCenter
            Layout.topMargin: root.horizontal ? 0 : 10
            Layout.bottomMargin: root.horizontal ? 0 : 10
            Layout.leftMargin: root.horizontal ? 6 : 0
            Layout.rightMargin: root.horizontal ? 6 : 0
            implicitWidth: root.horizontal ? 1 : 14
            implicitHeight: root.horizontal ? 14 : 1
            color: Appearance.outlineColor
        }

        StyledText {
            Layout.alignment: Qt.AlignCenter
            color: Appearance.mutedColor
            font.pixelSize: root.horizontal ? 11 : 10
            font.weight: Font.Medium
            font.letterSpacing: 1
            text: Time.format("ddd").toUpperCase()
        }

        StyledText {
            Layout.alignment: Qt.AlignCenter
            Layout.topMargin: root.horizontal ? 0 : 2
            font.pixelSize: 14
            font.weight: Font.DemiBold
            text: Time.format("d")
        }
    }
}
