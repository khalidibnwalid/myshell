pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool quickSettingsVisible: false
    property bool settingsVisible: false
    // page the Settings window should show next time it opens ("" keeps the current one)
    property string settingsPage: ""
    property bool searchVisible: false
    property bool clipboardVisible: false
    property int idlePauseRemainingSeconds: 0
    // the bar windows, so a panel's click-outside grab can leave the bar usable
    property var barWindows: []
    // small windows that belong to the bar (volume popup); they stay usable under a grab too
    property var barPopups: []

    function registerBarPopup(w) {
        barPopups = barPopups.concat([w]);
    }

    function unregisterBarPopup(w) {
        barPopups = barPopups.filter(p => p !== w);
    }

    function toggleIdlePause() {
        idlePauseRemainingSeconds = idlePauseRemainingSeconds > 0 ? 0 : 3600;
    }

    signal toggleQuickSettingsVisible
    signal setQuickSettingsVisible(bool visible)
    signal toggleSettingsVisible
    signal toggleSearchVisible
    // handled by the Idle module, which owns the lock screen
    signal lockRequested

    function openSettings(page) {
        settingsPage = page || "";
        settingsVisible = true;
    }

    onToggleQuickSettingsVisible: quickSettingsVisible = !quickSettingsVisible
    onSetQuickSettingsVisible: quickSettingsVisible = visible
    onToggleSettingsVisible: settingsVisible = !settingsVisible
    onToggleSearchVisible: searchVisible = !searchVisible

    Timer {
        interval: 1000
        repeat: true
        running: root.idlePauseRemainingSeconds > 0
        onTriggered: root.idlePauseRemainingSeconds = Math.max(0, root.idlePauseRemainingSeconds - 1)
    }

    function shutdownComputer() {
        shutdownProc.exec(["systemctl", "poweroff"]);
    }

    function restartComputer() {
        restartProc.exec(["systemctl", "reboot"]);
    }

    function suspendComputer() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function logOut() {
        Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
    }

    Process {
        id: shutdownProc
    }

    Process {
        id: restartProc
    }
}
