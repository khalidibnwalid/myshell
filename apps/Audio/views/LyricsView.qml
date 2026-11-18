import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The lyrics of the current track, in time with the song when they are synced (a click on a line seeks);
// when there are none, the cover and the title.
Item {
    ListView {
        id: lyricsView

        anchors.fill: parent
        visible: Player.lyrics.length > 0
        clip: true
        model: Player.lyrics
        currentIndex: Player.lyricsSynced ? Math.max(0, Player.lyricIndex) : 0
        highlightRangeMode: Player.lyricsSynced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - 30
        preferredHighlightEnd: height / 2 + 30
        highlightMoveDuration: 380
        highlightFollowsCurrentItem: true
        boundsBehavior: Flickable.StopAtBounds
        header: Item {
            height: Player.lyricsSynced ? lyricsView.height / 2 - 30 : 4
        }
        footer: Item {
            height: Player.lyricsSynced ? lyricsView.height / 2 : 4
        }

        delegate: Item {
            id: line

            required property var modelData
            required property int index
            readonly property bool current: Player.lyricsSynced && index === Player.lyricIndex

            width: lyricsView.width
            height: text.implicitHeight + 14

            StyledText {
                id: text

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 8
                text: line.modelData.text === "" ? "♪" : line.modelData.text
                wrapMode: Text.WordWrap
                horizontalAlignment: Player.lyricsSynced ? Text.AlignHCenter : Text.AlignLeft
                font.pixelSize: line.current ? 21 : 17
                font.weight: line.current ? Font.Bold : Font.Medium
                color: line.current ? Appearance.accentColor : Appearance.fgColor
                opacity: !Player.lyricsSynced || line.current ? 1 : 0.4

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animNormal
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: Player.lyricsSynced
                cursorShape: Qt.PointingHandCursor
                onClicked: Player.seek(line.modelData.t)
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 20
        visible: Player.lyrics.length === 0
        spacing: 8

        Cover {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 220
            Layout.preferredHeight: 220
            radius: 20
            source: Player.track ? Player.track.cover : ""
            symbolSize: 64
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 10
            horizontalAlignment: Text.AlignHCenter
            text: Player.track ? Player.track.title : "Nothing is playing"
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.pixelSize: 17
            font.weight: Font.Bold
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: Player.track !== null
            text: Player.track ? [Player.track.artist, Player.track.album].filter(x => x).join(" · ") : ""
            elide: Text.ElideRight
            color: Appearance.mutedColor
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 8
            horizontalAlignment: Text.AlignHCenter
            visible: Player.track !== null
            text: "No lyrics. Put a .lrc file with the same name next to the track."
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: Appearance.mutedColor
        }
    }
}
