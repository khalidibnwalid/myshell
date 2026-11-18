import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The artists, each with the number of tracks and albums; clicking one opens it.
ListView {
    id: artistList

    property var artists: []

    signal opened(string key)
    signal topReached

    function focusList() {
        forceActiveFocus();
        if (currentIndex < 0 && count > 0)
            currentIndex = 0;
    }

    clip: true
    spacing: 2
    model: artistList.artists
    boundsBehavior: Flickable.StopAtBounds
    activeFocusOnTab: true
    highlightFollowsCurrentItem: false
    Keys.onShortcutOverride: event => nav.override(event)
    Keys.onPressed: event => nav.press(event)

    ListNav {
        id: nav

        view: artistList
        rowHeight: 66
        onActivated: artistList.opened(artistList.artists[artistList.currentIndex].key)
        onTopReached: artistList.topReached()
    }

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    delegate: Rectangle {
        id: artistRow

        required property var modelData

        width: artistList.width - (artistList.ScrollBar.vertical.visible ? 10 : 0)
        height: 64
        radius: 14
        color: artistArea.containsMouse || (artistRow.ListView.isCurrentItem && artistList.activeFocus) ? Appearance.surfaceColor : "transparent"

        FocusRing {
            gap: 0
            visible: artistRow.ListView.isCurrentItem && artistList.activeFocus
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 14
            spacing: 14

            Cover {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 24
                source: artistRow.modelData.cover
                icon: "person"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: artistRow.modelData.name
                    elide: Text.ElideRight
                    font.weight: Font.Medium
                }

                StyledText {
                    text: artistRow.modelData.tracks.length + " tracks · " + artistRow.modelData.albumCount + (artistRow.modelData.albumCount === 1 ? " album" : " albums")
                    font.pixelSize: 12
                    color: Appearance.mutedColor
                }
            }

            MaterialSymbol {
                icon: "chevron_right"
                font.pixelSize: 20
                color: Appearance.mutedColor
            }
        }

        MouseArea {
            id: artistArea

            z: -1
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: artistList.opened(artistRow.modelData.key)
        }
    }

    Label {
        anchors.centerIn: parent
        visible: artistList.artists.length === 0
        text: "No artists"
        color: Appearance.mutedColor
    }
}
