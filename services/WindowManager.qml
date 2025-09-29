pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property bool quickSettingsVisible: false

    signal toggleQuickSettingsVisible()
    signal setQuickSettingsVisible(bool visible)

    onToggleQuickSettingsVisible: quickSettingsVisible = !quickSettingsVisible
    onSetQuickSettingsVisible: quickSettingsVisible = visible
}
