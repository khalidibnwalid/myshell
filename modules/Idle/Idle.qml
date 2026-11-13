import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Wayland

Scope {
    id: root

    property bool lockRequested: false
    property string password: ""
    property string statusText: ""
    property var pamContext: null

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
                    root.statusText = "";
                }
                onSubmitted: root.submitPassword()
            }
        }
    }
}
