import "../../../components"
import "../../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Scrollable settings page: title, optional subtitle and header controls,
// then the page's groups in a column of comfortable reading width.
Flickable {
    id: root

    property string title
    property string subtitle
    default property alias content: body.data
    property alias headerActions: actions.data

    contentHeight: column.implicitHeight + 56
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
    }

    ColumnLayout {
        id: column

        y: 28
        width: Math.min(root.width - 56, 800)
        x: Math.round((root.width - width) / 2)
        spacing: 22

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.subtitle
                    elide: Text.ElideRight
                    color: Appearance.mutedColor
                    font.pixelSize: 13
                }
            }

            RowLayout {
                id: actions

                spacing: 8
            }
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: 22
        }
    }
}
