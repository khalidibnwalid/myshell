import "../../../components"
import "../../../config"
import "../components"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The header of an open album or artist: the picture, the title, the totals, and Play / Shuffle.
Rectangle {
    id: root

    // "album" or "artist", and the album or artist itself
    property string kind: "album"
    property var item: null

    signal playRequested
    signal shuffleRequested

    Layout.fillWidth: true
        implicitHeight: 112
    radius: 20
    color: Appearance.surfaceColor

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 16

        Cover {
            Layout.preferredWidth: 84
            Layout.preferredHeight: 84
            radius: root.kind === "artist" ? 42 : 14
            source: root.item ? root.item.cover : ""
            icon: root.kind === "artist" ? "person" : "album"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.item ? (root.kind === "album" ? root.item.title : root.item.name) : ""
                elide: Text.ElideRight
                font.pixelSize: 20
                font.weight: Font.Bold
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (!root.item)
                        return "";
                    const it = root.item;
                    const n = it.tracks.length + (it.tracks.length === 1 ? " track" : " tracks");
                    if (root.kind === "album")
                        return [it.artist, it.year, n, Library.total(it.tracks)].filter(x => x).join(" · ");
                    return [n, it.albumCount + (it.albumCount === 1 ? " album" : " albums"), Library.total(it.tracks)].join(" · ");
                }
                elide: Text.ElideRight
                color: Appearance.mutedColor
            }

            RowLayout {
                Layout.topMargin: 8
                spacing: 8

                PillButton {
                    text: "Play"
                    icon: "play_arrow"
                    toggled: true
                    onClicked: root.playRequested()
                }

                PillButton {
                    text: "Shuffle"
                    icon: "shuffle"
                    onClicked: root.shuffleRequested()
                }
            }
        }
    }
}
