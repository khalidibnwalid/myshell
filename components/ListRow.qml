import "../config/"
import QtQuick
import QtQuick.Layouts

// Row in a grouped list: the first and last rows carry the group's outer corners.
Rectangle {
    id: root

    property string icon
    property real iconFill: 0
    property string title
    property string subtitle
    property string trailingText
    property string trailingIcon
    // room kept free on the right for a control placed over the row
    property real trailingSpace: 0
    property bool active: false
    property bool first: false
    property bool last: false
    property bool interactive: true
    readonly property color contentColor: active ? Appearance.accentContrastColor : Appearance.fgColor
    readonly property bool hovered: interactive && mouseArea.containsMouse

    signal clicked()

    implicitHeight: 56
    topLeftRadius: first ? 20 : 6
    topRightRadius: first ? 20 : 6
    bottomLeftRadius: last ? 20 : 6
    bottomRightRadius: last ? 20 : 6
    color: active ? (hovered ? Appearance.accentColorLight : Appearance.accentColor) : (hovered ? Appearance.surfaceHighColor : Appearance.surfaceColor)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18 + root.trailingSpace
        spacing: 14

        MaterialSymbol {
            visible: root.icon !== ""
            icon: root.icon
            fill: root.iconFill
            font.pixelSize: 20
            color: root.contentColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                font.weight: Font.Medium
                color: root.contentColor
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                elide: Text.ElideRight
                font.pixelSize: 12
                color: root.contentColor
                opacity: 0.65
            }
        }

        StyledText {
            visible: root.trailingText !== ""
            text: root.trailingText
            font.pixelSize: 12
            color: root.contentColor
            opacity: 0.65
        }

        MaterialSymbol {
            visible: root.trailingIcon !== ""
            icon: root.trailingIcon
            font.pixelSize: 18
            color: root.contentColor
            opacity: 0.65
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
        }
    }
}
