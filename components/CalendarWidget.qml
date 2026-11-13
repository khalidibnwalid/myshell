import "../config/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property int displayedMonth: new Date().getMonth()
    property int displayedYear: new Date().getFullYear()

    implicitWidth: 360
    implicitHeight: layout.implicitHeight + 20
    color: Appearance.surfaceColor
    radius: 22
    border.color: Appearance.hairlineColor
    border.width: 1

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 8

        // Header Section
        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: Qt.formatDate(new Date(grid.year, grid.month, 1), "MMMM yyyy")
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            IconButton {
                size: 30
                iconSize: 18
                icon: "chevron_left"
                onClicked: {
                    if (root.displayedMonth === 0) {
                        root.displayedMonth = 11;
                        root.displayedYear--;
                    } else {
                        root.displayedMonth--;
                    }
                }
            }

            IconButton {
                size: 30
                iconSize: 18
                icon: "chevron_right"
                onClicked: {
                    if (root.displayedMonth === 11) {
                        root.displayedMonth = 0;
                        root.displayedYear++;
                    } else {
                        root.displayedMonth++;
                    }
                }
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
                        color: Appearance.mutedColor
                        font.pixelSize: 9
                        font.bold: true
                        opacity: index === 0 || index === 6 ? 0.55 : 0.8
                    }

                }

            }

        }

        // The Month Grid
        MonthGrid {
            id: grid

            Layout.fillWidth: true
            Layout.preferredHeight: 180
            Layout.minimumHeight: 180
            Layout.maximumHeight: 180
            month: root.displayedMonth
            year: root.displayedYear

            delegate: Item {
                required property var model

                implicitWidth: 34
                implicitHeight: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    color: model.today ? Appearance.accentColor : (ma.containsMouse ? Appearance.surfaceHighColor : "transparent")
                    border.color: model.today ? Appearance.accentColor : "transparent"
                    border.width: 1
                    opacity: model.month === grid.month ? 1 : 0.28

                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        font.pixelSize: 11
                        font.weight: model.today ? Font.Bold : Font.Normal
                        color: model.today ? Appearance.onAccentColor : Appearance.fgColor
                    }

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Behavior on color {
                        ColorAnimation { duration: Appearance.animFast }
                    }

                }

            }

        }

    }

}
