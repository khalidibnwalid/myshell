import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The print queue, a card of its own between the notifications and the quick settings card.
// It shows only while something waits to print; each document can be cancelled.
Rectangle {
    id: card

    readonly property bool shown: Printers.jobs.length > 0

    visible: opacity > 0
    opacity: shown ? 1 : 0
    implicitHeight: printColumn.implicitHeight + 28
    // the same glass as the quick settings card above or below it
    radius: 28
    color: Qt.alpha(Appearance.bgColor, Math.max(0.35, Appearance.panelAlpha))
    border.color: Appearance.hairlineColor
    border.width: 1

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animFast
        }
    }

    // the queue moves while it is shown
    Timer {
        interval: 3000
        repeat: true
        running: WindowManager.quickSettingsVisible && Printers.jobs.length > 0
        onTriggered: Printers.refreshJobs()
    }

    ColumnLayout {
        id: printColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        anchors.leftMargin: 18
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                icon: "print"
                fill: 1
                font.pixelSize: 18
                color: Appearance.accentColor
            }

            StyledText {
                Layout.fillWidth: true
                text: Printers.jobs.length === 1 ? "1 document printing" : Printers.jobs.length + " documents printing"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            PillButton {
                visible: Printers.jobs.length > 1
                implicitHeight: 28
                text: "Cancel all"
                onClicked: {
                    for (const j of Printers.jobs)
                        Printers.cancelJob(j.id);
                }
            }
        }

        Repeater {
            model: Printers.jobs.slice(0, 4)

            RowLayout {
                id: jobRow

                required property var modelData

                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    icon: jobRow.modelData.active ? "progress_activity" : "schedule"
                    font.pixelSize: 16
                    color: Appearance.mutedColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: jobRow.modelData.title || ("Job " + jobRow.modelData.id)
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: (jobRow.modelData.active ? "Printing on " : "Waiting for ") + jobRow.modelData.printer.replace(/_/g, " ") + "  ·  " + SystemInfo.formatBytes(jobRow.modelData.size)
                        color: Appearance.mutedColor
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    icon: "close"
                    Accessible.name: "Cancel this document"
                    ToolTip.visible: hovered
                    ToolTip.text: "Cancel this document"
                    onClicked: Printers.cancelJob(jobRow.modelData.id)
                }
            }
        }

        StyledText {
            visible: Printers.jobs.length > 4
            text: "and " + (Printers.jobs.length - 4) + " more"
            color: Appearance.mutedColor
            font.pixelSize: 11
        }
    }
}
