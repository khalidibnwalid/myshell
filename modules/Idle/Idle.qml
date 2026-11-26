import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pam
import Quickshell.Wayland

Scope {
    id: root

    property bool lockRequested: false
    property string password: ""
    property string statusText: ""
    property var pamContext: null
    // pam_faillock: after too many wrong passwords the account is locked for a while (unlock_time in
    // /etc/security/faillock.conf, 10 minutes by default) and even the right password is refused.
    // Seconds left of that lock, -1 when only an administrator can lift it, 0 when not locked.
    property int lockedSeconds: 0

    function lockedText() {
        if (lockedSeconds < 0)
            return "Too many wrong passwords: the account is locked. An administrator can unlock it with faillock --user " + (Quickshell.env("USER") || "") + " --reset.";
        const m = Math.floor(lockedSeconds / 60);
        const sec = String(lockedSeconds % 60).padStart(2, "0");
        return "Too many wrong passwords. Try again in " + m + ":" + sec + ".";
    }

    // reads the failed tries the way pam_faillock counts them (deny, fail_interval, unlock_time)
    function checkFaillock() {
        faillockProc.running = false;
        faillockProc.running = true;
    }

    function lockNow() {
        if (lockRequested)
            return;
        WindowManager.quickSettingsVisible = false;
        WindowManager.settingsVisible = false;
        WindowManager.searchVisible = false;
        WindowManager.clipboardVisible = false;
        password = "";
        statusText = "";
        lockRequested = true;
        pauseMedia();
        checkFaillock();
    }

    // music and videos (browsers, mpv, the Audio app: every MPRIS player) stop when the screen locks
    function pauseMedia() {
        for (const player of Mpris.players.values) {
            if (player.isPlaying && player.canPause)
                player.pause();
        }
    }

    function startAuthentication() {
        if (!lockRequested || !sessionLock.secure)
            return;
        password = "";
        if (!pamContext)
            pamContext = pamFactory.createObject(root);
        if (!pamContext || !pamContext.start()) {
            statusText = "Couldn't start authentication. Check the system PAM login configuration.";
            if (pamContext) {
                pamContext.destroy();
                pamContext = null;
            }
            retryTimer.restart();
        }
    }

    function submitPassword() {
        if (!pamContext || !pamContext.responseRequired)
            return;
        // a try while the account is locked is refused anyway; keep the password for when it opens
        if (lockedSeconds !== 0)
            return;
        const response = password;
        password = "";
        statusText = "Checking…";
        pamContext.respond(response);
    }

    GlobalShortcut {
        name: "lock"
        onPressed: root.lockNow()
    }

    Connections {
        function onLockRequested() {
            root.lockNow();
        }

        target: WindowManager
    }

    IdleMonitor {
        timeout: Math.max(1, Config.idle.lockAfterMinutes) * 60
        enabled: Config.idle.enabled && Config.idle.lockAfterMinutes > 0 && WindowManager.idlePauseRemainingSeconds <= 0
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lockNow()
    }

    IdleMonitor {
        timeout: Math.max(1, Config.idle.screenOffAfterMinutes) * 60
        enabled: Config.idle.enabled && Config.idle.screenOffAfterMinutes > Config.idle.lockAfterMinutes
        respectInhibitors: true
        onIsIdleChanged: Hyprland.dispatch(isIdle ? "dpms off" : "dpms on")
    }

    Component {
        id: pamFactory

        PamContext {
            config: "login"
        }
    }

    Connections {
        target: root.pamContext

        function onCompleted(result) {
            if (result === PamResult.Success) {
                root.password = "";
                root.statusText = "";
                root.lockRequested = false;
                return;
            }

            root.password = "";
            root.statusText = result === PamResult.Failed ? "That password didn't match. Try again." : "Authentication is temporarily unavailable. Try again.";
            // this try may have been the one that locked the account, or it was locked already
            root.checkFaillock();
            if (root.pamContext) {
                root.pamContext.destroy();
                root.pamContext = null;
            }
            retryTimer.restart();
        }

        function onPamMessage() {
            if (root.pamContext?.messageIsError)
                root.statusText = root.pamContext.message;
        }
    }

    Process {
        id: faillockProc

        // prints the seconds the account stays locked: 0 when it is not, -1 when unlock_time is 0
        command: ["sh", "-c", "c=/etc/security/faillock.conf; "
            + "get() { v=$(sed -n \"s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\\([0-9]*\\).*/\\1/p\" \"$c\" 2>/dev/null | tail -n1); echo \"${v:-$2}\"; }; "
            + "faillock --user \"$1\" 2>/dev/null | awk -v now=\"$(date +%s)\" -v deny=\"$(get deny 3)\" -v ut=\"$(get unlock_time 600)\" -v fi=\"$(get fail_interval 900)\" "
            + "'$NF == \"V\" && $1 ~ /^[0-9]/ { cmd = \"date -d \\\"\" $1 \" \" $2 \"\\\" +%s\"; cmd | getline t; close(cmd); if (now - t <= fi) { n++; if (t > last) last = t } } "
            + "END { if (deny > 0 && n >= deny) { if (ut == 0) print -1; else if (last + ut > now) print last + ut - now; else print 0 } else print 0 }'",
            "sh", Quickshell.env("USER") || ""]

        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                root.lockedSeconds = isNaN(n) ? 0 : n;
                if (root.lockedSeconds !== 0)
                    root.statusText = root.lockedText();
            }
        }
    }

    // counts the lock down once a second; when it runs out the field takes a password again
    Timer {
        interval: 1000
        repeat: true
        running: root.lockRequested && root.lockedSeconds > 0
        onTriggered: {
            root.lockedSeconds--;
            if (root.lockedSeconds > 0) {
                root.statusText = root.lockedText();
            } else {
                root.statusText = "You can try again.";
                root.checkFaillock();
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 650
        onTriggered: root.startAuthentication()
    }

    WlSessionLock {
        id: sessionLock
        locked: root.lockRequested

        onSecureChanged: {
            if (secure)
                root.startAuthentication();
        }

        WlSessionLockSurface {
            color: Appearance.bgColor

            LockScreen {
                anchors.fill: parent
                password: root.password
                statusText: root.statusText
                prompt: root.pamContext?.message || ""
                inputEnabled: !!root.pamContext?.responseRequired
                showInput: !!root.pamContext?.responseVisible
                secure: sessionLock.secure
                onEdited: text => {
                    root.password = text;
                    if (root.lockedSeconds === 0)
                        root.statusText = "";
                }
                onSubmitted: root.submitPassword()
            }
        }
    }
}
