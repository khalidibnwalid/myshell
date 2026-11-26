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

    // the clock sits flat on a capsule or an inset bar, and is an island of its own on Islands
    readonly property bool flat: Appearance.barStyle === "capsule" || Appearance.barStyle === "inset"
    // the Islands style: as wide as the other islands (the bar minus its margins)
    readonly property bool island: Appearance.barStyle === "islands"
    // the shape's thickness across the bar: the room minus the gap to the screen edge
    readonly property int thick: Config.barSize - Appearance.barEdgeMargin - Appearance.barInnerMargin
    implicitWidth: island && !horizontal ? thick : (horizontal ? grid.implicitWidth + 28 : 40)
    implicitHeight: island && horizontal ? thick : (horizontal ? 36 : grid.implicitHeight + 32)
    radius: horizontal ? implicitHeight / 2 : Math.min(20, implicitWidth / 2)
    // on a see-through bar it is an island like the other groups
    readonly property real islandAmount: Appearance.barIslandAmount
    color: clockArea.containsMouse ? Appearance.surfaceHighColor : (flat ? "transparent" : (islandAmount > 0 ? Qt.alpha(Appearance.bgColor, 0.5 * islandAmount + 0.07 * (1 - islandAmount)) : Appearance.surfaceColor))
    border.width: islandAmount > 0 && !flat ? 1 : 0
    border.color: Qt.alpha(Appearance.fgColor, 0.1 * islandAmount)

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
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeFade
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
