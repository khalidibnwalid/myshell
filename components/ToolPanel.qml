import "../config/"
import QtQuick
import QtQuick.Layouts

// A titled card for a side panel (Tools, Layers, History…). Children go under the title.
// closable adds an x in the header that sends closed().
Rectangle {
    id: root

    property string title
    property bool closable: false
    default property alias content: body.data
    property alias headerActions: actions.data
    property int padding: 10

    signal closed()

    implicitWidth: 200
    implicitHeight: column.implicitHeight + padding * 2
    radius: 18
    color: Appearance.surfaceColor
    border.width: 1
    border.color: Appearance.hairlineColor

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: root.title
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Appearance.mutedColor
                elide: Text.ElideRight
            }

            RowLayout {
                id: actions

                spacing: 0
            }

            IconButton {
                visible: root.closable
                icon: "close"
                size: 26
                iconSize: 16
                onClicked: root.closed()
            }
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
        }
    }
}
