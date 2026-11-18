import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A list of tracks with Play all / Shuffle above it.
ColumnLayout {
    id: root

    property var tracks: []
    // Play all / Shuffle and the totals, shown above a list that is not an open album or artist
    property bool showActions: true
    property bool canClear: false
    property bool numbered: false
    property bool showAlbum: true
    property string emptyIcon: "library_music"
    property string emptyText: ""
    property string emptyHint: ""

    signal playRequested
    signal shuffleRequested
    signal clearRequested
    signal activated(int index)
    signal topReached

    function focusList() {
        tracksList.focusList();
    }

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        visible: root.showActions && root.tracks.length > 0
        spacing: 8

        PillButton {
            text: "Play all"
            icon: "play_arrow"
            onClicked: root.playRequested()
        }

        PillButton {
            text: "Shuffle"
            icon: "shuffle"
            onClicked: root.shuffleRequested()
        }

        StyledText {
            Layout.fillWidth: true
            text: root.tracks.length + " tracks · " + Library.total(root.tracks)
            color: Appearance.mutedColor
            font.pixelSize: 13
        }

        PillButton {
            visible: root.canClear
            text: "Clear"
            icon: "delete"
            onClicked: root.clearRequested()
        }
    }

    TrackList {
        id: tracksList

        Layout.fillWidth: true
        Layout.fillHeight: true
        tracks: root.tracks
        numbered: root.numbered
        showAlbum: root.showAlbum
        emptyIcon: root.emptyIcon
        emptyText: root.emptyText
        emptyHint: root.emptyHint
        onActivated: i => root.activated(i)
        onTopReached: root.topReached()
    }
}
