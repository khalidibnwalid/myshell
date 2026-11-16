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
    // text to put in that page's search box when it opens (used by the launcher's results)
    property string settingsQuery: ""
    // the pages of the Settings window that exist on this computer, for the launcher:
    // [{ key, name, icon, group, keywords }]
    property var settingsIndex: []
    property bool searchVisible: false
    property bool clipboardVisible: false
    property bool notepadVisible: false
    property bool processesVisible: false
    property bool timerVisible: false
    // the next time the System page opens, it shows its Detailed look
    property bool settingsDetailed: false
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
    // the Notepad window is already open: bring it to the front
    signal notepadRaiseRequested
    // the Processes window is already open: bring it to the front
    signal processesRaiseRequested
    // the Timer window is already open: bring it to the front
    signal timerRaiseRequested

    function openTimer() {
        if (timerVisible)
            timerRaiseRequested();
        else
            timerVisible = true;
    }

    function openProcesses() {
        if (processesVisible)
            processesRaiseRequested();
        else
            processesVisible = true;
    }

    function openNotepad() {
        if (notepadVisible)
            notepadRaiseRequested();
        else
            notepadVisible = true;
    }

    function openSettings(page, query) {
        settingsQuery = query || "";
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
