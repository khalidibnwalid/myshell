import "../../components/"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var stackView

    implicitHeight: layout.implicitHeight + 32

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 14

        PageHeader {
            Layout.fillWidth: true
            title: "Calendar"
            onBack: stackView.pop()
        }

        CalendarWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            Layout.maximumHeight: 280
        }
    }
}
