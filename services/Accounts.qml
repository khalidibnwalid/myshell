pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The signed-in user (as AccountsService and the passwd database have it), the other people
// who can sign in, and the online accounts set up with GNOME Online Accounts.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string faceFile: home + "/.face"
    readonly property string goaFile: home + "/.config/goa-1.0/accounts.conf"

    property string userName: ""
    property string realName: ""
    property string shell: ""
    property string hostname: ""
    property int uid: 0
    property bool admin: false
    property bool hasFace: false
    // bumped when the picture changes so the Image reloads it
    property int faceVersion: 0
    property var groups: []
    // [{ name, realName, admin }] people other than this user
    property var others: []
    // [{ id, provider, identity, services: ["Mail", ...] }]
    property var online: []
    // the program that opens the online accounts settings, or ""
    property string onlineTool: ""
    property string error: ""

    readonly property var providerNames: ({
            "google": "Google",
            "ms_graph": "Microsoft",
            "exchange": "Microsoft Exchange",
            "imap_smtp": "Email (IMAP)",
            "nextcloud": "Nextcloud",
            "owncloud": "ownCloud",
            "webdav": "WebDAV",
            "fedora": "Fedora",
            "kerberos": "Enterprise login",
            "ftp": "FTP"
        })
    readonly property var providerIcons: ({
            "google": "mail",
            "ms_graph": "mail",
            "exchange": "mail",
            "imap_smtp": "mail",
            "nextcloud": "cloud",
            "owncloud": "cloud",
            "webdav": "cloud",
            "ftp": "folder_shared"
        })

    function refresh() {
        userProc.running = true;
        onlineProc.running = true;
        toolProc.running = true;
    }

    function fail(what) {
        error = what;
        Quickshell.execDetached(["notify-send", "-a", "Accounts", "Could not change that", what]);
    }

    // AccountsService lets a user change their own name and picture without a password
    function setRealName(name) {
        if (name === realName)
            return;
        nameProc.command = ["busctl", "--system", "call", "org.freedesktop.Accounts", "/org/freedesktop/Accounts/User" + uid, "org.freedesktop.Accounts.User", "SetRealName", "s", name];
        nameProc.running = true;
    }

    // copied to ~/.face, which the lock screen and login screen read too
    function setFace(path) {
        faceProc.command = ["sh", "-c", "cp -f -- \"$1\" \"$2\" && busctl --system call org.freedesktop.Accounts /org/freedesktop/Accounts/User\"$3\" org.freedesktop.Accounts.User SetIconFile s \"$2\"", "sh", path, faceFile, String(uid)];
        faceProc.running = true;
    }

    function removeFace() {
        Quickshell.execDetached(["sh", "-c", "rm -f -- \"$1\"", "sh", faceFile]);
        hasFace = false;
        faceVersion++;
    }

    // asks for administrator rights through polkit
    function setHostname(name) {
        if (name === "" || name === hostname)
            return;
        hostProc.command = ["hostnamectl", "set-hostname", name];
        hostProc.running = true;
    }

    // passwd and chsh ask for the password, so they run in a terminal
    function inTerminal(cmd) {
        Quickshell.execDetached(["sh", "-c", "t=${TERMINAL:-$(command -v alacritty || command -v kitty || command -v foot || command -v xterm)}; exec \"$t\" -e sh -c \"$1\"", "sh", cmd]);
    }

    function changePassword() {
        inTerminal("passwd");
    }

    function changeShell(path) {
        inTerminal("chsh -s " + path);
    }

    function openOnline() {
        Quickshell.execDetached(["gnome-control-center", "online-accounts"]);
    }

    function parseGoa(text) {
        const rows = [];
        let cur = null;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            const head = /^\[Account (.+)\]$/.exec(line);
            if (head) {
                cur = {
                    "id": head[1],
                    "provider": "",
                    "identity": "",
                    "services": []
                };
                rows.push(cur);
                continue;
            }
            if (!cur)
                continue;
            const kv = /^([A-Za-z]+)=(.*)$/.exec(line);
            if (!kv)
                continue;
            if (kv[1] === "Provider")
                cur.provider = kv[2];
            else if (kv[1] === "PresentationIdentity" || (kv[1] === "Identity" && cur.identity === ""))
                cur.identity = kv[2];
            else if (kv[1].endsWith("Enabled") && kv[2] === "true")
                cur.services.push(kv[1].substring(0, kv[1].length - 7));
        }
        online = rows;
    }

    function parseOthers(text) {
        const rows = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const p = lines[i].split(":");
            if (p.length < 7)
                continue;
            const id = parseInt(p[2]);
            if (id < 1000 || id >= 60000 || p[0] === root.userName || p[6].endsWith("nologin") || p[6].endsWith("false"))
                continue;
            rows.push({
                "name": p[0],
                "realName": p[4].split(",")[0]
            });
        }
        others = rows;
    }

    Process {
        id: userProc

        command: ["sh", "-c", "getent passwd \"$(id -un)\"; echo ---; id -Gn; echo ---; hostnamectl hostname 2>/dev/null || cat /etc/hostname; echo ---; [ -f \"$HOME/.face\" ] && echo face"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---\n");
                const f = (parts[0] || "").trim().split(":");
                root.userName = f[0] || "";
                root.uid = parseInt(f[2]) || 0;
                root.realName = (f[4] || "").split(",")[0];
                root.shell = f[6] || "";
                root.groups = (parts[1] || "").trim().split(/\s+/).filter(g => g !== "");
                root.admin = root.groups.indexOf("wheel") >= 0 || root.groups.indexOf("sudo") >= 0;
                root.hostname = (parts[2] || "").trim();
                root.hasFace = (parts[3] || "").indexOf("face") >= 0;
                // needs the user name, to leave this user out
                othersProc.running = true;
            }
        }
    }

    Process {
        id: othersProc

        command: ["getent", "passwd"]

        stdout: StdioCollector {
            onStreamFinished: root.parseOthers(text)
        }
    }

    Process {
        id: onlineProc

        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "sh", root.goaFile]

        stdout: StdioCollector {
            onStreamFinished: root.parseGoa(text)
        }
    }

    Process {
        id: toolProc

        command: ["sh", "-c", "command -v gnome-control-center"]

        stdout: StdioCollector {
            onStreamFinished: root.onlineTool = text.trim()
        }
    }

    Process {
        id: nameProc

        stderr: StdioCollector {
            id: nameErr
        }
        onExited: code => {
            if (code !== 0)
                root.fail(nameErr.text.trim() || "The name was not changed");
            root.refresh();
        }
    }

    Process {
        id: faceProc

        stderr: StdioCollector {
            id: faceErr
        }
        onExited: code => {
            if (code !== 0)
                root.fail(faceErr.text.trim() || "The picture was not changed");
            root.hasFace = code === 0 || root.hasFace;
            root.faceVersion++;
        }
    }

    Process {
        id: hostProc

        stderr: StdioCollector {
            id: hostErr
        }
        onExited: code => {
            if (code !== 0)
                root.fail(hostErr.text.trim() || "The computer name was not changed");
            root.refresh();
        }
    }
}
