import "../../config/"
import QtQuick
import Quickshell
import Quickshell.Io

// The file dialogs of other apps (VS Code, Firefox, ...): xdg-desktop-portal asks helpers/portal-filechooser,
// which asks here, and the answer goes back the same way. Follows `fileChooser.enabled`: on, it writes the
// portal files and starts the helper; off, it stops the helper and removes the files again, so the GTK portal
// serves the dialogs (see the quickshell-glass-dialogs skill for the look).
Scope {
    id: root

    readonly property bool active: Config.fileChooser.enabled
    readonly property string runner: 'b=$("$1/helpers/portal-filechooser/build.sh") && exec "$b" "$2"'
    // requests waiting for the user, the first one is on screen
    property var queue: []
    // where the last dialog ended, the next one without a folder of its own starts there
    property string lastFolder: ""
    property int tries: 0

    function restartPortal() {
        Quickshell.execDetached(["systemctl", "--user", "restart", "xdg-desktop-portal"]);
    }

    function dirOf(path) {
        return path.replace(/\/[^\/]+$/, "") || "/";
    }

    function got(line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.close)
            queue = queue.filter(r => r.id !== m.id);
        else
            queue = queue.concat([m]);
    }

    function finish(paths) {
        const r = queue[0];
        if (!r)
            return;
        if (paths.length > 0)
            lastFolder = r.options?.directory ? paths[0] : dirOf(paths[0]);
        helper.write(JSON.stringify({
            "id": r.id,
            "paths": paths,
            "cancelled": paths.length === 0
        }) + "\n");
        queue = queue.slice(1);
    }

    onActiveChanged: {
        if (active) {
            tries = 0;
            setup.running = true;
        } else {
            helper.running = false;
            queue = [];
            removal.running = true;
        }
    }
    Component.onCompleted: if (active)
        setup.running = true

    // writes the portal files (prints "changed" when it wrote something new), then the helper takes the dialogs
    Process {
        id: setup

        command: ["sh", "-c", root.runner, "sh", Quickshell.shellDir, "install"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "changed")
                    root.restartPortal();
            }
        }
        // without Go the build fails at once: nothing starts and the GTK portal keeps serving
        onExited: code => {
            if (code === 0 && root.active)
                helper.running = true;
        }
    }

    Process {
        id: helper

        command: ["sh", "-c", root.runner, "sh", Quickshell.shellDir, ""]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.got(line)
        }
        onExited: {
            // nobody can answer the waiting dialogs now; the portal cancels them
            root.queue = [];
            if (root.active && root.tries++ < 3)
                retry.start();
        }
    }

    Timer {
        id: retry

        interval: 2000
        onTriggered: if (root.active)
            helper.running = true
    }

    Process {
        id: removal

        command: ["sh", "-c", root.runner, "sh", Quickshell.shellDir, "uninstall"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "changed")
                    root.restartPortal();
            }
        }
    }

    LazyLoader {
        active: root.queue.length > 0

        FileChooserWindow {
            request: root.queue[0]
            startFolder: root.lastFolder
            onChosen: paths => root.finish(paths)
            onCancelled: root.finish([])
        }
    }
}
