import "../../config/"
import "../../services/"
import QtQuick
import Quickshell.Services.Mpris

// A few small bars that move with what the speakers play, in the bar. Optional (Settings → Bar →
// Sound waves). They run along the bar: a column of bars on a side bar, a row on a top or bottom
// bar. Click them to pause or play the media that is playing (a video, a song). They stay (still)
// while something is paused, so there is something to click to carry on.
Item {
    id: root

    readonly property bool wanted: Config.bar.waves ?? false
    readonly property bool horizontal: Config.barHorizontal
    // the bars (12 by default), each the loudest of its bands, over the range of a voice (about 90 Hz to 3 kHz), each
    // band against its own recent peak so that speech moving up and down moves the bars
    readonly property int count: Math.max(4, Math.min(24, Config.bar.wavesBars ?? 12))
    // how far the bars swell across the bar
    readonly property int across: Math.max(14, Math.min(44, Config.bar.wavesWidth ?? 30))
    readonly property var levels: AudioWave.flow
    // the player to pause: the one that is playing, else the first
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) || players[0] || null
    property bool counted: false

    visible: wanted && (player !== null || !AudioWave.silent)
    // along the bar: the bars and the gaps between them
    readonly property int span: count * 3 + (count - 1) * 2
    implicitWidth: horizontal ? span : across
    implicitHeight: horizontal ? across : span

    function level(index) {
        // the voice range is bands 3 to 26, shared out over the bars
        const from = 3 + Math.floor(index * 24 / count);
        const to = Math.max(from + 1, 3 + Math.floor((index + 1) * 24 / count));
        let top = 0;
        for (let k = from; k < to; k++)
            top = Math.max(top, levels[k] ?? 0);
        return Math.pow(Math.max(0, (top - 0.03) / 0.97), 1.3);
    }

    function take() {
        if (!counted) {
            counted = true;
            AudioWave.use();
        }
    }

    function drop() {
        if (counted) {
            counted = false;
            AudioWave.release();
        }
    }

    // the sound is only listened to while the option is on
    onWantedChanged: {
        if (wanted)
            take();
        else
            drop();
    }
    Component.onCompleted: {
        if (wanted)
            take();
    }
    Component.onDestruction: drop()

    opacity: area.containsMouse ? 1 : 0.85

    // a top or bottom bar: a row of bars that swell up and down
    Row {
        visible: root.horizontal
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.visible && root.horizontal ? root.count : 0

            Rectangle {
                required property int index
                readonly property real level: root.level(index)

                width: 3
                height: Math.max(3, root.height * level)
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                color: Appearance.accentColor
                opacity: 0.45 + 0.55 * level

                // between two pictures of the sound, so the bars glide
                Behavior on height {
                    NumberAnimation {
                        duration: 70
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    // a side bar: a column of bars that swell sideways
    Column {
        visible: !root.horizontal
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.visible && !root.horizontal ? root.count : 0

            Rectangle {
                required property int index
                readonly property real level: root.level(index)

                height: 3
                width: Math.max(3, root.width * level)
                radius: 1.5
                anchors.horizontalCenter: parent.horizontalCenter
                color: Appearance.accentColor
                opacity: 0.45 + 0.55 * level

                Behavior on width {
                    NumberAnimation {
                        duration: 70
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        enabled: root.player !== null
        cursorShape: root.player !== null ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.player?.togglePlaying()
    }
}
