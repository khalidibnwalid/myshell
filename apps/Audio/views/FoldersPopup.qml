import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The audio folders: the ones in the library, with a way to remove them or add another.
Popup {
    id: root

    signal addRequested

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    width: 460
    padding: 18
    background: Rectangle {
        radius: 24
        color: Qt.alpha(Appearance.bgColor, 1)
        border.width: 1
        border.color: Appearance.hairlineColor
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: "Audio folders"
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            IconButton {
                icon: "sync"
                size: 34
                iconSize: 20
                onClicked: Library.refresh()
            }

            IconButton {
                icon: "close"
                size: 34
                iconSize: 20
                onClicked: root.close()
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "Tracks and videos in these folders and the folders inside them are in the library. A track is read once, and again only when its file changes."
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: Appearance.mutedColor
        }

        Repeater {
            model: Library.folders

            delegate: Rectangle {
                id: folderRow

                required property string modelData

                Layout.fillWidth: true
                implicitHeight: 44
                radius: 14
                color: Appearance.surfaceColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    spacing: 10

                    MaterialSymbol {
                        icon: "folder"
                        font.pixelSize: 20
                        color: Appearance.mutedColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: folderRow.modelData.replace(Library.home, "~")
                        elide: Text.ElideMiddle
                    }

                    StyledText {
                        text: Library.tracks.filter(t => t.path.startsWith(folderRow.modelData + "/")).length
                        font.pixelSize: 12
                        color: Appearance.mutedColor
                    }

                    IconButton {
                        icon: "close"
                        size: 30
                        iconSize: 18
                        onClicked: Library.removeFolder(folderRow.modelData)
                    }
                }
            }
        }

        PillButton {
            text: "Add a folder"
            icon: "add"
            onClicked: root.addRequested()
        }
    }
}
