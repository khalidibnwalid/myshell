import "../config/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    // Obsidian Entity Style - Compact version
    color: Appearance.highlightColor
    radius: 12
    border.color: Appearance.borderColor
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // Header Section
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: Qt.formatDateTime(new Date(), "MMMM yyyy")
                color: Appearance.accentColor
                font.pixelSize: 15
                font.bold: true
                Layout.fillWidth: true
            }

            MaterialSymbol {
                icon: "event"
                color: Appearance.fgColor
                font.pixelSize: 16
                opacity: 0.4
            }

        }

        // Days of Week Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]

                delegate: Item {
                    Layout.fillWidth: true
                    height: 14

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: Appearance.fgColor
                        font.pixelSize: 9
                        font.bold: true
                        opacity: index === 0 || index === 6 ? 0.3 : 0.5
                    }

                }

            }

        }

        // The Month Grid
        MonthGrid {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true
            month: new Date().getMonth()
            year: new Date().getFullYear()

            delegate: Item {
                implicitWidth: 34
                implicitHeight: 32

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: 8
                    color: model.today ? Appearance.accentColor : (ma.containsMouse ? Qt.alpha(Appearance.accentColor, 0.1) : "transparent")
                    border.color: model.today ? Appearance.accentColor : (ma.containsMouse ? Appearance.borderColor : "transparent")
                    border.width: 1
                    opacity: model.month === grid.month ? 1 : 0.2

                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        font.pixelSize: 12
                        font.weight: model.today ? Font.Bold : Font.Normal
                        color: model.today ? Appearance.bgColor : Appearance.fgColor
                    }

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }

                    }

                }

            }

        }

    }

}
