import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Layouts

// Scrollable settings page with a title; children go into the column.
Flickable {
    id: root

    property string title
    default property alias content: column.data

    contentHeight: column.implicitHeight + 56
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 28
        spacing: 3

        StyledText {
            Layout.bottomMargin: 17
            text: root.title
            font.pixelSize: 24
            font.weight: Font.Bold
        }
    }
}
