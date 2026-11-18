import "../../../config"
import "../../../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A list of tracks: the cover, title and artist, the album when there is room, the length, and
// buttons to favourite a track or to queue it. Clicking a row plays the list from there.
Item {
    id: root

    property var tracks: []
    property string emptyIcon: "library_music"
    property string emptyText: "No tracks"
    property string emptyHint: ""
    // the album and artist of a track are the same on every row of an album view
    property bool showAlbum: true
    property bool numbered: false
    readonly property alias view: list

    signal activated(int index)
    signal topReached

    function focusList() {
        list.forceActiveFocus();
        if (list.currentIndex < 0 && list.count > 0)
            list.currentIndex = 0;
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        spacing: 2
        model: root.tracks
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: 600
        activeFocusOnTab: true
        highlightFollowsCurrentItem: false
        // Enter plays from the row; F favourites it, Q queues it, N plays it next
        Keys.onShortcutOverride: event => nav.override(event)
        Keys.onPressed: event => {
            nav.press(event);
            const t = root.tracks[currentIndex];
            if (event.accepted || !t || event.modifiers !== Qt.NoModifier)
                return;
            if (event.key === Qt.Key_F)
                Library.toggleFavorite(t.path);
            else if (event.key === Qt.Key_Q)
                Player.enqueue(t.path, false);
            else if (event.key === Qt.Key_N)
                Player.enqueue(t.path, true);
            else
                return;
            event.accepted = true;
        }

        ListNav {
            id: nav

            view: list
            rowHeight: 58
            onActivated: root.activated(list.currentIndex)
            onTopReached: root.topReached()
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: Player.currentPath === modelData.path
            readonly property bool favorite: Library.favorites[modelData.path] === true
            readonly property bool hovered: hover.hovered

            width: list.width - (list.ScrollBar.vertical.visible ? 10 : 0)
            height: 56
            radius: 14
            color: current ? Qt.alpha(Appearance.accentColor, 0.18) : (hovered ? Appearance.surfaceColor : "transparent")

            HoverHandler {
                id: hover
            }

            FocusRing {
                gap: 0
                visible: row.ListView.isCurrentItem && list.activeFocus
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated(row.index)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 12

                StyledText {
                    visible: root.numbered
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.track > 0 ? row.modelData.track : row.index + 1
                    color: Appearance.mutedColor
                    font.pixelSize: 13
                }

                Cover {
                    visible: !root.numbered
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    source: row.modelData.cover
                    radius: 8

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        visible: row.current
                        color: Qt.alpha("black", 0.5)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            icon: Player.playing ? "graphic_eq" : "pause"
                            font.pixelSize: 22
                            color: "white"
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.title
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        font.weight: row.current ? Font.Bold : Font.Medium
                        color: row.current ? Appearance.accentColor : Appearance.fgColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.artist || "Unknown artist"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        font.pixelSize: 12
                        color: Appearance.mutedColor
                    }
                }

                StyledText {
                    visible: root.showAlbum && root.width > 640
                    Layout.preferredWidth: Math.min(220, root.width * 0.25)
                    text: row.modelData.album
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    font.pixelSize: 13
                    color: Appearance.mutedColor
                }

                MaterialSymbol {
                    visible: row.modelData.video
                    icon: "movie"
                    font.pixelSize: 16
                    color: Appearance.mutedColor
                }

                IconButton {
                    visible: row.hovered
                    icon: "playlist_play"
                    size: 32
                    iconSize: 20
                    onClicked: Player.enqueue(row.modelData.path, true)
                }

                IconButton {
                    visible: row.hovered
                    icon: "playlist_add"
                    size: 32
                    iconSize: 20
                    onClicked: Player.enqueue(row.modelData.path, false)
                }

                IconButton {
                    visible: row.hovered || row.favorite
                    icon: "favorite"
                    iconFill: row.favorite ? 1 : 0
                    toggled: row.favorite
                    size: 32
                    iconSize: 20
                    onClicked: Library.toggleFavorite(row.modelData.path)
                }

                StyledText {
                    Layout.preferredWidth: 46
                    horizontalAlignment: Text.AlignRight
                    text: Library.format(row.modelData.duration)
                    font.pixelSize: 13
                    color: Appearance.mutedColor
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.tracks.length === 0
        spacing: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            icon: root.emptyIcon
            font.pixelSize: 48
            color: Appearance.mutedColor
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.emptyText
            font.pixelSize: 16
            font.weight: Font.Medium
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.emptyHint !== ""
            text: root.emptyHint
            color: Appearance.mutedColor
        }
    }
}
