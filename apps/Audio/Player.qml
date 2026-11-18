pragma Singleton

import "../../services/"
import QtMultimedia
import QtQuick
import Quickshell
import Quickshell.Io

// The player: the queue, shuffle and repeat, the volume and speed, the sleep timer and the lyrics of
// the current track. It lives apart from the window, so sound goes on when the window is closed, and
// it remembers the queue and the place in the track across a restart (nothing is loaded until play).
Singleton {
    id: root

    readonly property string filePath: Library.dir + "/player.json"

    // the queue in the order it plays; `original` is the same without shuffle
    property var queue: []
    property var original: []
    property int index: -1
    property bool shuffle: false
    // "off" | "all" | "one"
    property string repeat: "off"
    property real volume: 0.8
    property bool muted: false
    property real speed: 1
    property bool loaded: false
    // the place kept from the last session, used when the track is first loaded
    property real resumeMs: 0
    property bool sourceSet: false
    property real pendingSeek: -1
    property string error: ""
    property real fade: 1
    property double sleepAt: 0
    property bool sleepAtEnd: false
    property double sleepNow: Date.now()

    readonly property string currentPath: index >= 0 && index < queue.length ? queue[index] : ""
    readonly property var track: currentPath === "" ? null : Library.byPath[currentPath] ?? Library.track(currentPath)
    readonly property bool playing: media.playbackState === MediaPlayer.PlayingState
    readonly property bool hasTrack: currentPath !== ""
    readonly property real positionMs: sourceSet ? media.position : resumeMs
    readonly property real durationMs: media.duration > 0 ? media.duration : (track ? track.duration * 1000 : 0)
    readonly property bool hasNext: index >= 0 && (index < queue.length - 1 || repeat !== "off")
    readonly property bool sleeping: sleepAt > 0 || sleepAtEnd
    readonly property string sleepLabel: sleepAtEnd ? "End of track" : (sleepAt > 0 ? Library.format(Math.max(0, (sleepAt - sleepNow) / 1000)) : "")

    // synced lyrics: [{ t (ms), text }], or the plain text split in lines (t: -1)
    property var lyrics: []
    property bool lyricsSynced: false
    readonly property int lyricIndex: {
        if (!lyricsSynced)
            return -1;
        const p = positionMs + 200;
        let at = -1;
        for (let i = 0; i < lyrics.length; i++) {
            if (lyrics[i].t <= p)
                at = i;
            else
                break;
        }
        return at;
    }

    function shuffled(list, first) {
        const rest = list.slice();
        const head = first !== undefined ? rest.splice(first, 1) : [];
        for (let i = rest.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const tmp = rest[i];
            rest[i] = rest[j];
            rest[j] = tmp;
        }
        return head.concat(rest);
    }

    // plays a list of tracks (paths), starting at `start`
    function playList(paths, start) {
        if (paths.length === 0)
            return;
        const at = Math.max(0, Math.min(start || 0, paths.length - 1));
        original = paths.slice();
        if (shuffle) {
            queue = shuffled(paths, at);
            index = 0;
        } else {
            queue = paths.slice();
            index = at;
        }
        startCurrent(true);
    }

    function playShuffled(paths) {
        if (paths.length === 0)
            return;
        shuffle = true;
        playList(paths, Math.floor(Math.random() * paths.length));
    }

    // files or folders from outside the library: index them, then play what was found
    function openPaths(paths, enqueueOnly) {
        const clean = paths.map(Library.cleanPath).filter(p => p !== "");
        if (clean.length === 0)
            return;
        pendingOpens = pendingOpens.concat([
            {
                "paths": clean,
                "enqueue": enqueueOnly === true
            }
        ]);
        Library.scanPaths(clean);
    }

    // files asked for and not indexed yet, in the order asked
    property var pendingOpens: []

    function enqueue(path, next) {
        if (!hasTrack) {
            playList([path], 0);
            return;
        }
        const at = next ? index + 1 : queue.length;
        const q = queue.slice();
        q.splice(at, 0, path);
        queue = q;
        const o = original.slice();
        if (next) {
            const at2 = original.indexOf(currentPath) + 1;
            o.splice(at2 > 0 ? at2 : o.length, 0, path);
        } else {
            o.push(path);
        }
        original = o;
        save();
    }

    function removeAt(i) {
        if (i < 0 || i >= queue.length)
            return;
        const path = queue[i];
        const q = queue.slice();
        q.splice(i, 1);
        const o = original.slice();
        const oi = o.indexOf(path);
        if (oi >= 0)
            o.splice(oi, 1);
        original = o;
        if (i === index) {
            queue = q;
            if (q.length === 0) {
                stop();
                index = -1;
            } else {
                index = Math.min(i, q.length - 1);
                startCurrent(playing);
            }
        } else {
            queue = q;
            if (i < index)
                index = index - 1;
        }
        save();
    }

    // `order[slot]` is the old position of the track now at that place (after a drag)
    function reorder(order) {
        const q = order.map(i => queue[i]);
        const playingNow = order.indexOf(index);
        queue = q;
        index = playingNow;
        save();
    }

    function clearQueue() {
        stop();
        queue = [];
        original = [];
        index = -1;
        sourceSet = false;
        resumeMs = 0;
        lyrics = [];
        save();
    }

    function jump(i) {
        if (i < 0 || i >= queue.length)
            return;
        index = i;
        startCurrent(true);
    }

    function setShuffle(on) {
        if (on === shuffle)
            return;
        shuffle = on;
        const cur = currentPath;
        if (on) {
            const at = queue.indexOf(cur);
            queue = shuffled(queue, at >= 0 ? at : undefined);
            index = at >= 0 ? 0 : index;
        } else {
            const rest = original.filter(p => queue.indexOf(p) >= 0);
            // tracks added while shuffled are already in `original`
            queue = rest.length === queue.length ? rest : queue;
            index = Math.max(0, queue.indexOf(cur));
        }
        save();
    }

    function cycleRepeat() {
        repeat = repeat === "off" ? "all" : (repeat === "all" ? "one" : "off");
        save();
    }

    function setVolume(v) {
        volume = Math.max(0, Math.min(1, v));
        if (volume > 0)
            muted = false;
        saveTimer.restart();
    }

    function setSpeed(s) {
        speed = s;
        save();
    }

    function ensureSource() {
        if (sourceSet || !hasTrack)
            return;
        pendingSeek = resumeMs;
        media.source = Library.url(currentPath);
        sourceSet = true;
    }

    // loads the current track; `play` starts it
    function startCurrent(playNow) {
        error = "";
        if (!hasTrack)
            return;
        resumeMs = 0;
        pendingSeek = -1;
        media.source = Library.url(currentPath);
        sourceSet = true;
        if (playNow) {
            media.play();
            Library.played(currentPath);
        }
        loadLyrics();
        save();
    }

    function play() {
        if (!hasTrack)
            return;
        if (!sourceSet) {
            ensureSource();
            loadLyrics();
        }
        // after the end of the last track, play it from the start
        if (media.mediaStatus === MediaPlayer.EndOfMedia)
            media.position = 0;
        media.play();
        Library.played(currentPath);
        fade = 1;
    }

    function pause() {
        media.pause();
        resumeMs = media.position;
        save();
    }

    function stop() {
        media.stop();
    }

    function toggle() {
        if (playing)
            pause();
        else
            play();
    }

    function next() {
        advance(false);
    }

    function previous() {
        if (!hasTrack)
            return;
        if (positionMs > 3000 || queue.length < 2) {
            seek(0);
            return;
        }
        if (index > 0)
            jump(index - 1);
        else if (repeat === "all")
            jump(queue.length - 1);
        else
            seek(0);
    }

    // the track ended (auto) or the next button was pressed
    function advance(auto) {
        if (!hasTrack)
            return;
        if (auto && sleepAtEnd) {
            sleepAtEnd = false;
            media.pause();
            resumeMs = 0;
            if (index < queue.length - 1)
                index = index + 1;
            startCurrent(false);
            return;
        }
        if (auto && repeat === "one") {
            media.position = 0;
            media.play();
            return;
        }
        if (index < queue.length - 1) {
            jump(index + 1);
        } else if (repeat === "all" || (!auto && queue.length > 1)) {
            if (shuffle && repeat === "all")
                queue = shuffled(original);
            jump(0);
        } else if (auto) {
            // the end of the queue
            media.stop();
            resumeMs = 0;
            sourceSet = true;
        }
    }

    function seek(ms) {
        if (!hasTrack)
            return;
        const target = Math.max(0, Math.min(ms, durationMs > 0 ? durationMs : ms));
        mprisSeeked = true;
        mprisTimer.restart();
        if (!sourceSet) {
            resumeMs = target;
            return;
        }
        media.position = target;
    }

    function setSleep(minutes) {
        sleepAtEnd = false;
        sleepAt = 0;
        if (minutes === -1) {
            sleepAtEnd = true;
        } else if (minutes > 0) {
            sleepAt = Date.now() + minutes * 60000;
            sleepNow = Date.now();
            sleepTimer.interval = minutes * 60000;
            sleepTimer.restart();
            return;
        }
        sleepTimer.stop();
    }

    function fireSleep() {
        sleepAt = 0;
        fadeOut.restart();
    }

    function loadLyrics() {
        lyrics = [];
        lyricsSynced = false;
        if (!hasTrack)
            return;
        lyricsProc.path = currentPath;
        lyricsProc.running = false;
        lyricsProc.command = ["sh", "-c", "f=\"$1\"; b=\"${f%.*}\"; for e in lrc LRC; do [ -f \"$b.$e\" ] && { head -c 200000 \"$b.$e\"; exit 0; }; done; ffprobe -v error -show_entries format_tags=lyrics,LYRICS,unsyncedlyrics,UNSYNCEDLYRICS,lyrics-eng -of default=nw=1:nk=1 -i \"$f\" 2>/dev/null | head -c 200000", "sh", currentPath];
        lyricsProc.running = true;
    }

    function parseLyrics(text) {
        const synced = [];
        const plain = [];
        const stamp = /\[(\d+):(\d+(?:[.:]\d+)?)\]/g;
        for (const raw of text.split(/\r?\n/)) {
            const line = raw.trim();
            const times = [];
            let m;
            stamp.lastIndex = 0;
            while ((m = stamp.exec(line)) !== null)
                times.push((parseInt(m[1]) * 60 + parseFloat(m[2].replace(":", "."))) * 1000);
            const words = line.replace(/\[[^\]]*\]/g, "").replace(/<\d+:\d+(?:\.\d+)?>/g, "").trim();
            if (times.length > 0) {
                for (const t of times)
                    synced.push({
                        "t": t,
                        "text": words
                    });
            } else if (!/^\[[a-z]+:.*\]$/i.test(line)) {
                plain.push({
                    "t": -1,
                    "text": line
                });
            }
        }
        if (synced.length > 1) {
            synced.sort((a, b) => a.t - b.t);
            lyricsSynced = true;
            lyrics = synced;
        } else {
            lyricsSynced = false;
            while (plain.length > 0 && plain[plain.length - 1].text === "")
                plain.pop();
            lyrics = plain.length > 0 && plain.some(l => l.text !== "") ? plain : [];
        }
    }

    function save() {
        if (!loaded)
            return;
        saveTimer.stop();
        writer.setText(JSON.stringify({
            "queue": queue,
            "original": original,
            "index": index,
            "position": Math.round(sourceSet ? media.position : resumeMs),
            "shuffle": shuffle,
            "repeat": repeat,
            "volume": volume,
            "muted": muted,
            "speed": speed
        }));
    }

    function load() {
        if (!loaded && !loadProc.running)
            loadProc.running = true;
    }

    // ---- MPRIS: mpris.py shows this player to the system (the media card, playerctl, media keys)
    property bool mprisQueueDirty: true
    property bool mprisSeeked: false
    property int mprisTries: 0

    function mprisSend(obj) {
        if (mprisProc.running)
            mprisProc.write(JSON.stringify(obj) + "\n");
    }

    function trackInfo(path) {
        const t = Library.byPath[path] ?? Library.track(path);
        return {
            "path": t.path,
            "title": t.title,
            "artist": t.artist,
            "album": t.album,
            "albumArtist": t.albumArtist,
            "genre": t.genre,
            "track": t.track,
            "disc": t.disc,
            "duration": t.duration,
            "url": Library.url(t.path),
            "art": t.cover ? Library.url(t.cover) : ""
        };
    }

    function pushMpris() {
        const msg = {
            "state": {
                "status": playing ? "Playing" : (hasTrack ? "Paused" : "Stopped"),
                "path": currentPath,
                "index": index,
                "pos": Math.round(positionMs),
                "rate": speed,
                "volume": muted ? 0 : volume,
                "shuffle": shuffle,
                "loop": repeat === "one" ? "Track" : (repeat === "all" ? "Playlist" : "None"),
                "canNext": queue.length > 1 || hasNext,
                "canPrev": hasTrack,
                "track": hasTrack ? trackInfo(currentPath) : null,
                "seeked": mprisSeeked
            }
        };
        mprisSeeked = false;
        if (mprisQueueDirty) {
            mprisQueueDirty = false;
            msg.queue = queue.map(trackInfo);
        }
        mprisSend(msg);
    }

    function mprisCommand(line) {
        let c;
        try {
            c = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (c.cmd) {
        case "ready":
            mprisTries = 0;
            mprisQueueDirty = true;
            pushMpris();
            break;
        case "play":
            play();
            break;
        case "pause":
            pause();
            break;
        case "playpause":
            toggle();
            break;
        case "stop":
            pause();
            seek(0);
            break;
        case "next":
            next();
            break;
        case "previous":
            previous();
            break;
        case "seek":
            seek(positionMs + c.ms);
            break;
        case "setposition":
            seek(c.ms);
            break;
        case "volume":
            setVolume(c.v);
            break;
        case "shuffle":
            setShuffle(c.v === true);
            break;
        case "loop":
            repeat = c.v === "Track" ? "one" : (c.v === "Playlist" ? "all" : "off");
            save();
            break;
        case "rate":
            setSpeed(Math.max(0.25, Math.min(4, c.v)));
            break;
        case "goto":
            jump(c.index);
            break;
        case "remove":
            removeAt(c.index);
            break;
        case "open":
            openPaths([c.uri], false);
            break;
        case "add":
            openPaths([c.uri], !c.current);
            break;
        case "raise":
            WindowManager.openAudio();
            break;
        case "quit":
            WindowManager.audioVisible = false;
            break;
        }
    }

    onPlayingChanged: mprisTimer.restart()
    onCurrentPathChanged: mprisTimer.restart()
    onTrackChanged: mprisTimer.restart()
    onIndexChanged: mprisTimer.restart()
    onSpeedChanged: mprisTimer.restart()
    onVolumeChanged: mprisTimer.restart()
    onMutedChanged: mprisTimer.restart()
    onShuffleChanged: mprisTimer.restart()
    onRepeatChanged: mprisTimer.restart()
    onQueueChanged: {
        mprisQueueDirty = true;
        mprisTimer.restart();
    }

    Timer {
        id: mprisTimer

        interval: 80
        onTriggered: root.pushMpris()
    }

    // the clients extrapolate the position; this corrects any drift
    Timer {
        interval: 10000
        repeat: true
        running: root.playing
        onTriggered: root.pushMpris()
    }

    Timer {
        id: mprisRetry

        interval: 3000
        onTriggered: mprisProc.running = true
    }

    Connections {
        function onByPathChanged() {
            root.mprisQueueDirty = true;
            mprisTimer.restart();
        }

        target: Library
    }

    Process {
        id: mprisProc

        command: ["/usr/bin/python3", Quickshell.shellDir + "/apps/Audio/scripts/mpris.py"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.mprisCommand(line)
        }
        onExited: code => {
            // without python-gobject it fails at once: three tries, then it is left off
            if (root.mprisTries++ < 3)
                mprisRetry.start();
        }
    }

    MediaPlayer {
        id: media

        playbackRate: root.speed
        audioOutput: AudioOutput {
            volume: root.muted ? 0 : root.volume * root.volume * root.fade
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                root.advance(true);
            } else if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) && root.pendingSeek > 0) {
                media.position = root.pendingSeek;
                root.pendingSeek = -1;
            }
        }
        onErrorOccurred: (error, errorString) => {
            root.error = errorString || "This file cannot be played";
            // a broken track does not stop the queue
            skipTimer.restart();
        }
    }

    Timer {
        id: skipTimer

        interval: 1200
        onTriggered: {
            if (root.error !== "" && root.index < root.queue.length - 1)
                root.jump(root.index + 1);
        }
    }

    // the place in the track is saved every few seconds while it plays
    Timer {
        interval: 5000
        repeat: true
        running: root.playing
        onTriggered: root.save()
    }

    Timer {
        id: saveTimer

        interval: 800
        onTriggered: root.save()
    }

    Timer {
        id: sleepTimer

        onTriggered: root.fireSleep()
    }

    // the minutes left of the sleep timer count only while something shows them
    Timer {
        interval: 1000
        repeat: true
        running: root.sleepAt > 0
        onTriggered: root.sleepNow = Date.now()
    }

    SequentialAnimation {
        id: fadeOut

        NumberAnimation {
            target: root
            property: "fade"
            to: 0
            duration: 5000
        }
        ScriptAction {
            script: {
                root.pause();
                root.fade = 1;
            }
        }
    }

    Process {
        id: lyricsProc

        property string path: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (lyricsProc.path === root.currentPath)
                    root.parseLyrics(this.text);
            }
        }
    }

    Process {
        id: loadProc

        command: ["sh", "-c", "mkdir -p \"$1\"; cat \"$1/player.json\" 2>/dev/null", "sh", Library.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try {
                    d = this.text.trim() === "" ? {} : JSON.parse(this.text);
                } catch (e) {
                    Quickshell.execDetached(["cp", root.filePath, root.filePath + ".corrupt"]);
                }
                const list = v => Array.isArray(v) ? v.map(String) : [];
                root.queue = list(d.queue);
                root.original = list(d.original).length > 0 ? list(d.original) : root.queue.slice();
                root.index = root.queue.length > 0 ? Math.max(0, Math.min(parseInt(d.index) || 0, root.queue.length - 1)) : -1;
                root.resumeMs = Number(d.position) || 0;
                root.shuffle = d.shuffle === true;
                root.repeat = ["off", "all", "one"].indexOf(d.repeat) >= 0 ? d.repeat : "off";
                root.volume = typeof d.volume === "number" ? Math.max(0, Math.min(1, d.volume)) : 0.8;
                root.muted = d.muted === true;
                root.speed = typeof d.speed === "number" && d.speed > 0 ? d.speed : 1;
                root.loaded = true;
                root.loadLyrics();
                mprisProc.running = true;
            }
        }
    }

    // files opened from outside the library are played once they have been indexed
    Connections {
        function onPathsScanned(paths) {
            const mine = p => root.pendingOpens.find(o => o.paths.some(x => p === x || p.startsWith(x + "/")));
            const open = paths.length > 0 ? mine(paths[0]) : root.pendingOpens[0];
            if (!open)
                return;
            root.pendingOpens = root.pendingOpens.filter(o => o !== open);
            const own = paths.filter(p => open.paths.some(x => p === x || p.startsWith(x + "/")));
            if (own.length === 0)
                return;
            if (open.enqueue)
                own.forEach(p => root.enqueue(p, false));
            else
                root.playList(own, 0);
        }

        target: Library
    }

    FileView {
        id: writer

        path: root.filePath
        preload: false
        atomicWrites: true
        printErrors: false
    }
}
