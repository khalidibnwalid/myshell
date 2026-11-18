import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The albums as a grid of covers; clicking one opens it, the round button plays it.
GridView {
    id: grid

    property var albums: []

    signal opened(string key)
    signal topReached

    function focusList() {
        forceActiveFocus();
        if (currentIndex < 0 && count > 0)
            currentIndex = 0;
    }

    readonly property int columns: Math.max(2, Math.floor(width / 176))

    clip: true
    model: grid.albums
    cellWidth: Math.floor(width / columns)
    cellHeight: cellWidth + 56
    boundsBehavior: Flickable.StopAtBounds
    activeFocusOnTab: true
    highlightFollowsCurrentItem: false
    Keys.onShortcutOverride: event => nav.override(event)
    Keys.onPressed: event => nav.press(event)

    ListNav {
        id: nav

        view: grid
        horizontal: true
        onActivated: grid.opened(grid.albums[grid.currentIndex].key)
        onTopReached: grid.topReached()
    }

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    delegate: Item {
        id: card

        required property var modelData

        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 18
            color: cardArea.containsMouse || (card.GridView.isCurrentItem && grid.activeFocus) ? Appearance.surfaceColor : "transparent"

            FocusRing {
                gap: 0
                visible: card.GridView.isCurrentItem && grid.activeFocus
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Cover {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    radius: 12
                    source: card.modelData.cover
                    icon: "album"

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: 40
                        height: 40
                        radius: 20
                        color: Appearance.accentColor
                        opacity: cardArea.containsMouse ? 1 : 0
                        scale: cardArea.containsMouse ? 1 : 0.8

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animFast
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animFast
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            icon: "play_arrow"
                            fill: 1
                            font.pixelSize: 24
                            color: Appearance.accentContrastColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Player.shuffle = false;
                                Player.playList(card.modelData.tracks.map(t => t.path), 0);
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: card.modelData.title
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: card.modelData.artist || (card.modelData.tracks.length + " tracks")
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: Appearance.mutedColor
                    }
                }
            }

            MouseArea {
                id: cardArea

                z: -1
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: grid.opened(card.modelData.key)
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: grid.albums.length === 0
        text: "No albums"
        color: Appearance.mutedColor
    }
}
