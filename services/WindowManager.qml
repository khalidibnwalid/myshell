pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property bool quickSettingsVisible: false
    property bool settingsVisible: false
    property bool searchVisible: false
    property bool clipboardVisible: false
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

    signal toggleQuickSettingsVisible
    signal setQuickSettingsVisible(bool visible)
    signal toggleSettingsVisible
    signal toggleSearchVisible

    onToggleQuickSettingsVisible: quickSettingsVisible = !quickSettingsVisible
    onSetQuickSettingsVisible: quickSettingsVisible = visible
    onToggleSettingsVisible: settingsVisible = !settingsVisible
    onToggleSearchVisible: searchVisible = !searchVisible

    function shutdownComputer() {
        shutdownProc.exec(["systemctl", "poweroff"]);
    }

    function restartComputer() {
        restartProc.exec(["systemctl", "reboot"]);
    }

    Process {
        id: shutdownProc
    }

    Process {
        id: restartProc
    }
}
