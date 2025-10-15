pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property bool quickSettingsVisible: false
    property bool settingsVisible: false

    signal toggleQuickSettingsVisible
    signal setQuickSettingsVisible(bool visible)
    signal toggleSettingsVisible

    onToggleQuickSettingsVisible: quickSettingsVisible = !quickSettingsVisible
    onSetQuickSettingsVisible: quickSettingsVisible = visible
    onToggleSettingsVisible: settingsVisible = !settingsVisible

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
