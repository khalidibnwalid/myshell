import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The sections (tracks, albums, artists, favourites, recently played) and the button for the folders.
// It folds away: Layout.preferredWidth follows `open`.
Item {
    id: root

    property bool open: true
    property var sections: []
    property string section: ""

    signal selected(string id)
    signal foldRequested
    signal foldersRequested

    Layout.fillHeight: true
    Layout.preferredWidth: root.open ? 210 : 0
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    clip: true

    Behavior on Layout.preferredWidth {
        NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        width: 210
        height: parent.height
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.bottomMargin: 8
            Layout.topMargin: 4

            MaterialSymbol {
                icon: "graphic_eq"
                fill: 1
                font.pixelSize: 24
                color: Appearance.accentColor
            }

            StyledText {
                Layout.fillWidth: true
                text: "Audio"
                font.pixelSize: 20
                font.weight: Font.Bold
            }

            IconButton {
                icon: "left_panel_close"
                size: 34
                iconSize: 20
                onClicked: root.foldRequested()
            }
        }

        Repeater {
            model: root.sections

            delegate: Rectangle {
                id: nav

                required property var modelData
                readonly property bool current: root.section === modelData.id

                Layout.fillWidth: true
                implicitHeight: 42
                radius: 14
                color: current ? Appearance.accentColor : (navArea.containsMouse ? Appearance.surfaceHighColor : "transparent")
                activeFocusOnTab: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.selected(nav.modelData.id);
                        event.accepted = true;
                    }
                }
                Keys.onShortcutOverride: event => {
                    if (event.key === Qt.Key_Space)
                        event.accepted = true;
                }

                FocusRing {
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    MaterialSymbol {
                        icon: nav.modelData.icon
                        fill: nav.current ? 1 : 0
                        font.pixelSize: 20
                        color: nav.current ? Appearance.accentContrastColor : Appearance.fgColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: nav.modelData.label
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                        color: nav.current ? Appearance.accentContrastColor : Appearance.fgColor
                    }

                    StyledText {
                        text: nav.modelData.count
                        font.pixelSize: 12
                        color: nav.current ? Appearance.accentContrastColor : Appearance.mutedColor
                    }
                }

                MouseArea {
                    id: navArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(nav.modelData.id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: 14
            color: foldersArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                MaterialSymbol {
                    icon: "create_new_folder"
                    font.pixelSize: 20
                    color: Appearance.mutedColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Library.scanning ? "Indexing…" : "Folders"
                    color: Appearance.mutedColor
                }

                MaterialSymbol {
                    visible: Library.scanning
                    icon: "sync"
                    font.pixelSize: 18
                    color: Appearance.accentColor

                    RotationAnimator on rotation {
                        running: Library.scanning
                        from: 0
                        to: 360
                        duration: 1200
                        loops: Animation.Infinite
                    }
                }
            }

            MouseArea {
                id: foldersArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.foldersRequested()
            }
        }

        StyledText {
            Layout.leftMargin: 14
            Layout.bottomMargin: 6
            text: Library.tracks.length + " tracks · " + Library.total(Library.tracks)
            font.pixelSize: 12
            color: Appearance.mutedColor
        }
    }
}
