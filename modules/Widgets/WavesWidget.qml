import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick

// The sound-wave widget, straight on the wallpaper, drawn with bars that move with what the speakers
// play: "bars" (a row, swelling up and down), "vertical" (a column swelling sideways) and "circular"
// (a ring, growing outward). `u` is the size.
Item {
    id: root

    property real u: 1
    property var look: ({})
    readonly property color fg: look.fg ?? Appearance.fgColor
    readonly property color accent: look.accent ?? Appearance.accentColor
    readonly property color muted: Qt.alpha(fg, 0.62)
    property string style: "bars"
    // a style that no longer exists (the old line styles) shows as bars
    readonly property string kind: style === "vertical" || style === "circular" ? style : "bars"
    readonly property var levels: AudioWave.levels
    // the bar options of this widget: how much of its slot a bar fills, how many there are, round or square ends
    readonly property real fill: look.barFill ?? 0.7
    readonly property int count: look.barCount ?? 32
    readonly property bool round: look.barRound ?? true
    // how much louder tones stand out from quiet ones: 1 keeps the sound as it is, higher pushes the quiet ones down
    readonly property real contrast: look.contrast ?? 1.5
    // the bars swell a little on a bass hit, and the ring pulses
    readonly property real beat: (look.pulse ?? true) ? AudioWave.beat : 0

    // a colour between two, t from 0 to 1: the bars go from the accent (low pitches) to the text colour (high)
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }


    // the level of bar `i` of `count`: the bands are shared out evenly, so fewer bars take the loudest of their share
    function levelAt(i) {
        const per = AudioWave.bands / count;
        let top = 0;
        for (let k = Math.floor(i * per); k < Math.floor((i + 1) * per); k++)
            top = Math.max(top, levels[k] ?? 0);
        // a small floor first, so a faint hiss is no bar at all, then a power curve
        const stretched = Math.max(0, (top - 0.04) / 0.96);
        return Math.min(1, Math.pow(stretched, contrast) * (1 + 0.12 * beat));
    }

    implicitWidth: kind === "vertical" ? 150 * u : kind === "circular" ? 320 * u : 360 * u
    implicitHeight: kind === "vertical" ? 420 * u : kind === "circular" ? 320 * u : 120 * u

    // Listening and drawing only while the desktop is in front. A window over it hides the widget,
    // so a moment after that the capture stops, and starts again when the desktop shows.
    readonly property bool wanted: DesktopWidgets.desktopShown
    property bool counted: false

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

    onWantedChanged: {
        if (wanted) {
            hold.stop();
            take();
        } else {
            hold.restart();
        }
    }
    Component.onCompleted: {
        if (wanted)
            take();
    }
    Component.onDestruction: drop()

    Timer {
        id: hold

        interval: 2000
        onTriggered: root.drop()
    }

    // the height of the envelope at a place along the trace (0-1), curved between the bands
    function envelope(t) {
        const n = AudioWave.bands;
        const x = Math.max(0, Math.min(n - 1, t * (n - 1)));
        const i = Math.floor(x);
        const f = x - i;
        const a = levels[i] ?? 0;
        const b = levels[Math.min(n - 1, i + 1)] ?? 0;
        const s = f * f * (3 - 2 * f);
        return a + (b - a) * s;
    }

    // --- bars, in a row: swell up and down from a middle line, with a cap that hangs on at the top ---
    Row {
        visible: root.kind === "bars"
        anchors.centerIn: parent

        Repeater {
            model: root.kind === "bars" ? root.count : 0

            Item {
                id: slot

                required property int index
                readonly property real level: root.levelAt(index)
                readonly property color tint: root.mix(root.accent, root.fg, slot.index / Math.max(1, root.count - 1))

                width: root.width / root.count
                height: root.height

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(1.5 * root.u, slot.width * root.fill)
                    height: Math.max(width, root.height * slot.level)
                    radius: root.round ? width / 2 : Math.min(2 * root.u, width / 2)
                    color: slot.tint
                    opacity: 0.25 + 0.75 * slot.level
                }

            }
        }
    }

    // --- vertical: a column of bars that grow sideways, low pitches at the top ---
    Column {
        visible: root.kind === "vertical"
        anchors.centerIn: parent

        Repeater {
            model: root.kind === "vertical" ? root.count : 0

            Item {
                id: vslot

                required property int index
                readonly property real level: root.levelAt(index)
                readonly property color tint: root.mix(root.accent, root.fg, vslot.index / Math.max(1, root.count - 1))

                width: root.width
                height: root.height / root.count

                Rectangle {
                    anchors.centerIn: parent
                    height: Math.max(1.5 * root.u, vslot.height * root.fill)
                    width: Math.max(height, root.width * vslot.level)
                    radius: root.round ? height / 2 : Math.min(2 * root.u, height / 2)
                    color: vslot.tint
                    opacity: 0.25 + 0.75 * vslot.level
                }

            }
        }
    }

    // --- circular: bars grow outward from a ring that pulses on the bass ---
    Item {
        id: ring

        visible: root.kind === "circular"
        anchors.centerIn: parent
        // the pulse is a scale of the whole ring (one transform), not a new size for every bar
        scale: 1 + 0.06 * root.beat
        readonly property real radius: Math.min(root.width, root.height) * 0.26
        readonly property real reach: Math.min(root.width, root.height) * 0.22
        readonly property int total: root.count * 2

        // a thin ring under the bars that lights up on the beat
        Rectangle {
            anchors.centerIn: parent
            width: 2 * (ring.radius - 5 * root.u)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, 1.5 * root.u)
            border.color: root.accent
            opacity: 0.12 + 0.5 * root.beat
        }

        Repeater {
            model: root.kind === "circular" ? ring.total : 0

            Item {
                id: spoke

                required property int index
                readonly property int band: index < root.count ? index : ring.total - 1 - index
                readonly property real level: root.levelAt(band)
                readonly property real thick: Math.max(1.5 * root.u, 2 * Math.PI * ring.radius / ring.total * root.fill)

                rotation: index * 360 / ring.total

                Rectangle {
                    x: -width / 2
                    y: -(ring.radius + height)
                    width: spoke.thick
                    height: Math.max(width, ring.reach * spoke.level)
                    radius: root.round ? width / 2 : Math.min(2 * root.u, width / 2)
                    color: root.mix(root.accent, root.fg, spoke.band / Math.max(1, root.count - 1))
                    opacity: 0.25 + 0.75 * spoke.level
                }

            }
        }
    }

    StyledText {
        visible: AudioWave.failed
        anchors.centerIn: parent
        text: "No audio to listen to"
        color: root.muted
        font.pixelSize: 14 * root.u
    }
}
