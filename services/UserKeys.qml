pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// SSH keys in ~/.ssh and GPG keys in the user's keyring, for Settings → Passwords & keys.
// Public keys are copied with wl-copy; private keys never leave their files.
Singleton {
    id: root

    readonly property string sshDir: Quickshell.env("HOME") + "/.ssh"

    // [{ file, name, type, bits, fingerprint, comment, hasPrivate, modified }]
    property var ssh: []
    // [{ id, fingerprint, uids: [string], algo, bits, created, expires, secret, revoked, expired }]
    property var gpg: []
    property bool gpgAvailable: false
    property bool sshAvailable: false
    property bool loaded: false
    property string message: ""

    function refresh() {
        sshProc.running = true;
        gpgProc.running = true;
    }

    function run(command, done, input) {
        const p = actionComponent.createObject(root, {
            "command": command,
            "done": done || "",
            "input": input || ""
        });
        p.running = true;
    }

    function copySsh(key) {
        run(["sh", "-c", 'wl-copy < "$1"', "sh", key.file], "Copied the public key “" + key.name + "”");
    }

    function trashSsh(key) {
        const files = [key.file];
        if (key.hasPrivate)
            files.push(key.file.replace(/\.pub$/, ""));
        run(["gio", "trash"].concat(files), "“" + key.name + "” moved to the trash");
    }

    // ed25519 key; the passphrase (may be empty) goes through stdin, not the command line
    function createSsh(name, comment, passphrase) {
        const file = sshDir + "/" + name;
        run(["sh", "-c", 'mkdir -p -m 700 "$1" && [ ! -e "$2" ] || { echo "A key named $(basename "$2") already exists" >&2; exit 1; }; IFS= read -r p; if [ -n "$3" ]; then exec ssh-keygen -q -t ed25519 -C "$3" -f "$2" -N "$p"; else exec ssh-keygen -q -t ed25519 -f "$2" -N "$p"; fi', "sh", sshDir, file, comment], "Key “" + name + "” made", passphrase + "\n");
    }

    function copyGpg(key) {
        run(["sh", "-c", 'gpg --armor --export "$1" | wl-copy', "sh", key.fingerprint], "Copied the public key of " + (key.uids[0] || key.id));
    }

    // a key you only have the public half of; secret keys are left to Passwords and Keys or gpg
    function deleteGpg(key) {
        run(["gpg", "--batch", "--yes", "--delete-keys", key.fingerprint], "Deleted " + (key.uids[0] || key.id));
    }

    function finished(code, err, done) {
        if (code === 0) {
            if (done)
                message = done;
        } else {
            message = err.trim().split("\n").pop() || "That did not work";
        }
        refresh();
    }

    Component {
        id: actionComponent

        Process {
            property string done: ""
            property string input: ""

            stdinEnabled: input !== ""
            onStarted: {
                if (input !== "") {
                    write(input);
                    stdinEnabled = false;
                }
            }
            onExited: code => {
                root.finished(code, errors.text, done);
                destroy();
            }

            stderr: StdioCollector {
                id: errors
            }
        }
    }

    Process {
        id: sshProc

        command: ["sh", "-c", 'command -v ssh-keygen >/dev/null || exit 3; for f in "$1"/*.pub; do [ -f "$f" ] || continue; p=no; [ -f "${f%.pub}" ] && p=yes; printf "%s\\t%s\\t%s\\t%s\\n" "$f" "$p" "$(stat -c %Y "$f")" "$(ssh-keygen -lf "$f" 2>/dev/null)"; done', "sh", root.sshDir]

        stdout: StdioCollector {
            onStreamFinished: root.parseSsh(text)
        }
        onExited: code => root.sshAvailable = code !== 3
    }

    function parseSsh(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f.length < 4 || f[3] === "")
                continue;
            // 256 SHA256:abc comment words (ED25519)
            const m = f[3].match(/^(\d+) (\S+) (.*) \(([^)]+)\)$/);
            if (!m)
                continue;
            out.push({
                "file": f[0],
                "name": f[0].split("/").pop().replace(/\.pub$/, ""),
                "hasPrivate": f[1] === "yes",
                "modified": parseInt(f[2]),
                "bits": parseInt(m[1]),
                "fingerprint": m[2],
                "comment": m[3] === "no comment" ? "" : m[3],
                "type": m[4]
            });
        }
        ssh = out;
        loaded = true;
    }

    Process {
        id: gpgProc

        command: ["sh", "-c", 'command -v gpg >/dev/null || exit 3; gpg --batch --list-keys --with-colons --fixed-list-mode 2>/dev/null; echo ---; gpg --batch --list-secret-keys --with-colons --fixed-list-mode 2>/dev/null | grep "^fpr"']

        stdout: StdioCollector {
            onStreamFinished: root.parseGpg(text)
        }
        onExited: code => root.gpgAvailable = code !== 3
    }

    function parseGpg(text) {
        const parts = text.split("\n---\n");
        const secrets = {};
        for (const line of (parts[1] || "").split("\n")) {
            const f = line.split(":");
            if (f[0] === "fpr")
                secrets[f[9]] = true;
        }
        const out = [];
        let key = null;
        let wantFpr = false;
        for (const line of parts[0].split("\n")) {
            const f = line.split(":");
            if (f[0] === "pub") {
                key = {
                    "id": f[4],
                    "fingerprint": "",
                    "uids": [],
                    "bits": parseInt(f[2]) || 0,
                    "algo": f[16] || "",
                    "created": parseInt(f[5]) || 0,
                    "expires": parseInt(f[6]) || 0,
                    "revoked": f[1] === "r",
                    "expired": f[1] === "e",
                    "secret": false
                };
                out.push(key);
                wantFpr = true;
            } else if (f[0] === "sub") {
                wantFpr = false;
            } else if (f[0] === "fpr" && key && wantFpr) {
                key.fingerprint = f[9];
                key.secret = secrets[f[9]] === true;
                wantFpr = false;
            } else if (f[0] === "uid" && key && f[1] !== "r") {
                key.uids.push(f[9].replace(/\\x3a/g, ":"));
            }
        }
        gpg = out;
    }
}
