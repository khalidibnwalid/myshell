pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io

// Screen filter through a running hyprsunset (`hyprctl hyprsunset …`):
// colour temperature in kelvin and screen brightness ("gamma") in percent.
// The values live in config.json and are applied when the shell starts.
Singleton {
    id: root

    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6500
    readonly property int minGamma: 40
    readonly property int maxGamma: 100
    // what the reset button goes back to
    readonly property int defaultTemperature: 5500
    readonly property int defaultGamma: 80
    readonly property bool active: Config.display.nightLight
    readonly property int temperature: Config.display.nightLightTemperature
    readonly property int gamma: Config.display.nightLightGamma
    readonly property bool isDefault: temperature === defaultTemperature && gamma === defaultGamma
    // false when hyprsunset is not running
    property bool available: false

    function refresh() {
        probe.running = true;
    }

    function setActive(on) {
        Config.display.nightLight = on;
    }

    function setTemperature(kelvin) {
        Config.display.nightLightTemperature = Math.round(Math.max(minTemperature, Math.min(maxTemperature, kelvin)) / 50) * 50;
        Config.display.nightLight = true;
    }

    function setGamma(percent) {
        Config.display.nightLightGamma = Math.round(Math.max(minGamma, Math.min(maxGamma, percent)));
        Config.display.nightLight = true;
    }

    function reset() {
        Config.display.nightLightTemperature = defaultTemperature;
        Config.display.nightLightGamma = defaultGamma;
        Config.display.nightLight = true;
    }

    function apply() {
        if (!available)
            return;
        if (active)
            Quickshell.execDetached(["sh", "-c", "hyprctl hyprsunset temperature \"$1\"; hyprctl hyprsunset gamma \"$2\"", "sh", String(temperature), String(gamma)]);
        else
            Quickshell.execDetached(["sh", "-c", "hyprctl hyprsunset identity; hyprctl hyprsunset gamma 100"]);
    }

    onActiveChanged: applyTimer.restart()
    onTemperatureChanged: applyTimer.restart()
    onGammaChanged: applyTimer.restart()
    onAvailableChanged: applyTimer.restart()
    Component.onCompleted: refresh()

    // dragging a slider sends one command per pause, not one per pixel
    Timer {
        id: applyTimer

        interval: 60
        onTriggered: root.apply()
    }

    Process {
        id: probe

        command: ["hyprctl", "hyprsunset", "temperature"]

        stdout: StdioCollector {
            onStreamFinished: root.available = !isNaN(parseInt(text.trim()))
        }
    }
}
