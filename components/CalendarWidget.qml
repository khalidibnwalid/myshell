import "../config/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    clip: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Month Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8

            Text {
                text: Qt.formatDateTime(new Date(), "MMMM yyyy")
                color: Appearance.fgColor
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
                opacity: 0.9
            }

            MaterialSymbol {
                icon: "today"
                color: Appearance.accentColor
                font.pixelSize: 20
                opacity: 0.6
                Layout.rightMargin: 4
            }

        }

        // Days Header (Standardized English letters for clean look)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 0

            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]

                delegate: Text {
                    text: modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.fgColor
                    font.pixelSize: 11
                    font.bold: true
                    opacity: 0.3
                }

            }

        }

        // The Grid
        MonthGrid {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true
            month: new Date().getMonth()
            year: new Date().getFullYear()

            delegate: Item {
                implicitWidth: 32
                implicitHeight: 32

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: model.today ? Appearance.accentColor : "transparent"

                    // Interaction Ring
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.color: Appearance.accentColor
                        border.width: 1
                        visible: ma.containsMouse && !model.today
                        opacity: 0.5
                    }

                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        font.pixelSize: 13
                        font.weight: model.today ? Font.Bold : Font.Normal
                        color: model.today ? Appearance.bgColor : Appearance.fgColor
                        opacity: model.month === grid.month ? 1 : 0.25
                    }

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                }

            }

        }

    }

}
