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
