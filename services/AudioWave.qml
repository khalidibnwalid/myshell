pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The heights (0-1) of audio bars for what the speakers play, for the sound-wave widget. A small
// Go helper (helpers/audio-wave) turns the output monitor, recorded by pw-record, into bands.
// Nothing runs until a widget asks: call `use()` when it appears and `release()` when it goes.
Singleton {
    id: root

    readonly property int bands: 32
    // smoothed heights, low pitches first; the widget reads this
    property var levels: new Array(bands).fill(0)
    property int users: 0
    readonly property bool active: users > 0
    // false while the process could not be started (no PipeWire, no Go), so the widget can say so
    property bool failed: false
    property bool silent: true
    property int restarts: 0

    function use() {
        users++;
    }

    function release() {
        users = Math.max(0, users - 1);
    }

    // Normalisation: the loudest recent band is stretched to the top of the range, so a quiet song, a loud
    // one and the system volume all move the bars the same. The reference rises at once with a louder
    // sound and falls within a few seconds, and never drops below `floor`. What the speakers play is
    // taken after the system volume, so a low volume is a quiet signal: the floor is low so that it is
    // still stretched to the full height. Below `gate` it is silence or hiss, which is left alone.
    property real reference: 0.5
    readonly property real floor: 0.07
    readonly property real gate: 0.05

    // What the pictures use besides the bars, all worked out here once for every widget:
    // beat: 1 on a bass hit, falling back to 0 within a third of a second;
    property real beat: 0
    // flow: the same bands, but each one against its own recent average (about a second): a steady sound
    // sits at the middle of the height, a voice that gets louder goes up and a quieter one comes down, so the
    // bars follow the voice and are not full all the time. Rises and falls are both quick but eased.
    property var flow: new Array(bands).fill(0)
    property var flowMean: new Array(bands).fill(0)
    property real bassAverage: 0
    property var fallSpeed: new Array(bands).fill(0)

    // one frame from the helper (about 40 a second)
    function frame(line) {
        const raw = line.split(" ");
        let top = 0;
        const v = new Array(bands);
        for (let i = 0; i < bands; i++) {
            v[i] = parseFloat(raw[i]) || 0;
            top = Math.max(top, v[i]);
        }
        // hiss and silence: no bars, and the reference keeps falling
        if (top < gate)
            top = 0;
        reference = Math.max(floor, top, reference * 0.992);
        const gain = top === 0 ? 0 : 1 / reference;
        for (let i = 0; i < bands; i++)
            v[i] = Math.min(1, v[i] * gain);
        // "monstercat" smoothing: a loud band pulls its neighbours up behind it, so the bars make hills
        // and not needles. Each step away keeps 60% of the height.
        const spread = new Array(bands);
        for (let i = 0; i < bands; i++) {
            let m = v[i];
            for (let d = 1; d <= 2; d++) {
                const k = Math.pow(0.6, d);
                if (i - d >= 0)
                    m = Math.max(m, v[i - d] * k);
                if (i + d < bands)
                    m = Math.max(m, v[i + d] * k);
            }
            spread[i] = m;
        }
        // gravity: a bar rises at once and falls faster the longer it has been falling
        const next = new Array(bands);
        let loud = false;
        for (let i = 0; i < bands; i++) {
            if (spread[i] >= levels[i]) {
                // a rise overshoots a little, so a hit pops and then settles
                next[i] = Math.min(1, spread[i] + (spread[i] - levels[i]) * 0.15);
                fallSpeed[i] = 0;
            } else {
                fallSpeed[i] += 0.0024;
                next[i] = Math.max(spread[i], levels[i] - fallSpeed[i]);
            }
            if (next[i] > 0.01)
                loud = true;
        }
        // beat: the bass jumps over its recent average
        let bass = 0;
        for (let i = 0; i < 4; i++)
            bass += spread[i];
        bass /= 4;
        const hit = bass > bassAverage * 1.3 + 0.1 && bass > 0.35;
        bassAverage = bassAverage * 0.955 + bass * 0.045;
        // all quiet and was quiet: nothing to redraw
        if (!loud && silent)
            return;
        silent = !loud;
        // the beat falls back within a third of a second; it is only set when it changes
        const nb = hit ? 1 : (beat < 0.03 ? 0 : beat * 0.86);
        if (nb !== beat)
            beat = nb;
        levels = next;
        // flow comes from the bands before the music-style fall of `next`, which is too slow for speech: a
        // syllable is a few hundred milliseconds, so it rises in about 2 frames and falls in about 6
        const own = new Array(bands);
        for (let i = 0; i < bands; i++) {
            flowMean[i] = flowMean[i] * 0.98 + spread[i] * 0.02;
            const target = Math.min(1, spread[i] / Math.max(0.12, 2.2 * flowMean[i]));
            own[i] = flow[i] + (target - flow[i]) * (target > flow[i] ? 0.6 : 0.35);
        }
        flow = own;
    }

    onActiveChanged: {
        if (active) {
            restarts = 0;
            failed = false;
            proc.running = true;
        } else {
            proc.running = false;
            levels = new Array(bands).fill(0);
            flow = new Array(bands).fill(0);
            flowMean = new Array(bands).fill(0);
            fallSpeed = new Array(bands).fill(0);
            beat = 0;
            silent = true;
            reference = 0.5;
        }
    }

    Timer {
        id: retry

        interval: 2000
        onTriggered: proc.running = root.active
    }

    Process {
        id: proc

        // the helper is built on the first run; the sink's monitor is recorded as mono, 22 kHz
        command: ["sh", "-c", 'b=$("$1/helpers/audio-wave/build.sh" "$2") && pw-record --raw -P "{ stream.capture.sink=true }" --rate 22050 --channels 1 --format s16 --latency 20ms - | setpriv --pdeathsig KILL "$b" "$3"', "sh", Quickshell.shellDir, (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/audio", String(root.bands)]
        stdout: SplitParser {
            onRead: line => root.frame(line)
        }
        onExited: code => {
            if (!root.active)
                return;
            root.restarts++;
            root.failed = root.restarts >= 4;
            if (!root.failed)
                retry.start();
        }
    }
}
