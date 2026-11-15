pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A picture to preview for a file: the thumbnail the file manager made, the image itself,
// or the cover of audio and video (made once and kept in the cache, for the first few only).
// The shell commands below are shared by the file search and the recent files source.
Singleton {
    id: root

    // run before `loop`
    readonly property string setup: "cache=\"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/thumbs\"; mkdir -p \"$cache\"; n=0; "
    // reads lines "type TAB path" and prints "type TAB path TAB preview TAB mime"
    readonly property string loop: "while IFS=\"$(printf '\\t')\" read -r y p; do " +
        "t=; m=; " +
        "if [ \"$y\" != d ]; then " +
        "i=$(gio info -a standard::content-type,thumbnail::path,thumbnail::is-valid \"$p\" 2>/dev/null); " +
        "m=$(echo \"$i\" | sed -n 's/^ *standard::content-type: //p'); " +
        "c=$(echo \"$i\" | sed -n 's/^ *thumbnail::path: //p'); " +
        "if [ -n \"$c\" ] && echo \"$i\" | grep -q 'is-valid: TRUE' && [ -f \"$c\" ]; then t=$c; " +
        "else case \"$m\" in " +
        "image/*) t=$p;; " +
        "audio/*|video/*) if [ $n -lt 6 ]; then o=\"$cache/$(printf %s \"$p\" | md5sum | cut -d' ' -f1).png\"; " +
        "[ -s \"$o\" ] || ffmpegthumbnailer -i \"$p\" -o \"$o\" -s 128 >/dev/null 2>&1; [ -s \"$o\" ] && t=$o; fi;; " +
        "esac; fi; n=$((n+1)); fi; " +
        "printf '%s\\t%s\\t%s\\t%s\\n' \"$y\" \"$p\" \"$t\" \"$m\"; done"

    // previews for some paths; done({ path: { preview, mime } }) when they are known
    function lookup(paths, done) {
        if (paths.length === 0)
            return;
        const proc = lookupProc.createObject(root, {
            "done": done,
            "command": ["sh", "-c", setup + "printf 'f\\t%s\\n' \"$@\" | " + loop, "sh"].concat(paths)
        });
        proc.running = true;
    }

    Component {
        id: lookupProc

        Process {
            id: proc

            required property var done

            stdout: StdioCollector {
                onStreamFinished: {
                    const found = {};
                    for (const line of text.split("\n")) {
                        const f = line.split("\t");
                        if (f.length >= 4 && f[1] !== "")
                            found[f[1]] = {
                                "preview": f[2],
                                "mime": f[3]
                            };
                    }
                    proc.done(found);
                    proc.destroy();
                }
            }
        }
    }
}
