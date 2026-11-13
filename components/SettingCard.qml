import "../config/"
import QtQuick
import QtQuick.Layouts

// Free-form row of a settings group: same surface and corners as SettingRow,
// with whatever content the page needs stacked inside.
Rectangle {
    id: root

    property bool first: false
    property bool last: false
    property int padding: 16
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + padding * 2
    topLeftRadius: first ? 22 : 6
    topRightRadius: first ? 22 : 6
    bottomLeftRadius: last ? 22 : 6
    bottomRightRadius: last ? 22 : 6
    color: Appearance.surfaceColor

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.padding + 4
        anchors.rightMargin: root.padding
        spacing: 10
    }
}
