import "../config/"
import QtQuick
import QtQuick.Layouts

// One row of a settings group: label + description on the left, a control on the right.
Rectangle {
    id: root

    property string title
    property string description
    property bool first: false
    property bool last: false
    default property alias control: controlRow.data

    implicitHeight: Math.max(60, labels.implicitHeight + 24)
    topLeftRadius: first ? 22 : 6
    topRightRadius: first ? 22 : 6
    bottomLeftRadius: last ? 22 : 6
    bottomRightRadius: last ? 22 : 6
    color: Appearance.surfaceColor

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 16
        spacing: 16

        ColumnLayout {
            id: labels

            Layout.fillWidth: true
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.Medium
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.description
                wrapMode: Text.Wrap
                color: Appearance.mutedColor
                font.pixelSize: 12
            }
        }

        RowLayout {
            id: controlRow

            spacing: 6
        }
    }
}
