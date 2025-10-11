pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property bool quickSettingsVisible: false
    property bool settingsVisible: false

    signal toggleQuickSettingsVisible()
    signal setQuickSettingsVisible(bool visible)
    signal toggleSettingsVisible()

    onToggleQuickSettingsVisible: quickSettingsVisible = !quickSettingsVisible
    onSetQuickSettingsVisible: quickSettingsVisible = visible
    onToggleSettingsVisible: settingsVisible = !settingsVisible
}
