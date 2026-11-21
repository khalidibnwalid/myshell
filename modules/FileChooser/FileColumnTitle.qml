import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts

// A column title of the file list: click it to sort by it (click again to reverse); the active one is accent
// coloured with an arrow.
MouseArea {
    id: root

    property string label
    property string key
    property bool alignRight: false
    property string sortBy
    property bool sortReversed: false
    readonly property bool active: sortBy === key

    Layout.fillHeight: true
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: "Sort by " + label

    RowLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            Layout.fillWidth: true
            visible: root.alignRight
        }

        StyledText {
            text: root.label
            font.pixelSize: 12
            font.weight: root.active ? Font.DemiBold : Font.Medium
            color: root.active ? Appearance.accentColor : (root.containsMouse ? Appearance.fgColor : Appearance.mutedColor)
        }

        MaterialSymbol {
            visible: root.active
            icon: root.sortReversed ? "arrow_downward" : "arrow_upward"
            font.pixelSize: 14
            color: Appearance.accentColor
        }

        Item {
            Layout.fillWidth: true
            visible: !root.alignRight
        }
    }
}
