pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The keyboard backlight (the leds device named *kbd_backlight), if the laptop has one.
// It can be turned off after a while without typing and comes back on the next key.
Singleton {
    id: root

    // e.g. "platform::kbd_backlight"
    property string device: ""
    property int level: 0
    property int maxLevel: 0
    readonly property bool available: device !== "" && maxLevel > 0
    // 0 = never
    readonly property int idleSeconds: Config.keyboard?.lightIdleSeconds ?? 0
    // the level to bring back after the idle switch-off
    property int savedLevel: -1
    property bool idle: false

    // The laptop has its own auto mode (Fn+Space cycles Off, Low, High, Auto): the controller
    // follows the light sensor by itself, even before Linux starts, and the kernel only
    // shows it as brightness 0. So by default the shell does not touch the light.
    // Once a level is picked here the laptop leaves its auto mode (Fn+Space brings it back).
    // "Auto (shell)" below does the same job in software, for when the laptop's is gone.
    property bool owned: false
    // nobody here has set the light: the laptop is in charge (its auto mode reads as 0)
    readonly property bool untouched: !owned && !auto && level === 0
    readonly property bool auto: (Config.keyboard?.lightAuto ?? false) && luxAvailable
    // switch on in rooms darker than this many lux
    readonly property real autoLux: Config.keyboard?.lightAutoLux ?? 20
    property real lux: -1
    property bool luxAvailable: false

    function refresh() {
        readProc.running = true;
    }

    function setLevel(n) {
        if (!available)
            return;
        const value = Math.max(0, Math.min(maxLevel, Math.round(n)));
        owned = true;
        level = value;
        setProc.exec(["brightnessctl", "-d", device, "set", String(value)]);
    }

    // the person picked a level: Auto ends
    function setManual(n) {
        Config.setIn("keyboard", "lightAuto", false);
        setLevel(n);
    }

    function setAuto(on) {
        Config.setIn("keyboard", "lightAuto", on);
        if (on)
            luxProc.running = true;
    }

    function setAutoLux(v) {
        Config.setIn("keyboard", "lightAutoLux", v);
    }

    // the level the room's light asks for; null = leave it as it is (between the two limits)
    function levelForLux(l) {
        if (l < 0)
            return null;
        if (l < autoLux / 4)
            return maxLevel;
        if (l < autoLux)
            return Math.min(1, maxLevel);
        if (l >= autoLux * 1.5)
            return 0;
        return null;
    }

    function followLight() {
        if (!auto || idle || !available)
            return;
        const wanted = levelForLux(lux);
        if (wanted !== null && wanted !== level)
            setLevel(wanted);
    }

    function setIdleSeconds(seconds) {
        Config.setIn("keyboard", "lightIdleSeconds", seconds);
    }

    Process {
        id: setProc
    }

    Process {
        id: readProc

        command: ["sh", "-c", "d=$(ls /sys/class/leds 2>/dev/null | grep -m1 kbd_backlight); [ -n \"$d\" ] || exit 0; echo \"$d\"; cat \"/sys/class/leds/$d/brightness\"; cat \"/sys/class/leds/$d/max_brightness\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split(/\r?\n/);
                if (lines.length < 3) {
                    root.device = "";
                    root.maxLevel = 0;
                    return;
                }
                root.device = lines[0].trim();
                root.level = Number(lines[1]) || 0;
                root.maxLevel = Number(lines[2]) || 0;
            }
        }
    }

    Process {
        id: luxProc

        command: ["sh", "-c", "for d in /sys/bus/iio/devices/iio:device*; do [ -r $d/in_illuminance_raw ] || continue; r=$(cat $d/in_illuminance_raw); s=$(cat $d/in_illuminance_scale 2>/dev/null || echo 1); o=$(cat $d/in_illuminance_offset 2>/dev/null || echo 0); echo \"$r $s $o\"; break; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/).map(Number);
                if (f.length < 3 || f.some(isNaN)) {
                    root.luxAvailable = false;
                    root.lux = -1;
                    return;
                }
                root.luxAvailable = true;
                root.lux = (f[0] + f[2]) * f[1];
                root.followLight();
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.available && root.auto
        onTriggered: luxProc.running = true
    }

    // no typing for a while: switch the light off, and back on at the next key or touch
    IdleMonitor {
        enabled: root.available && root.idleSeconds > 0
        timeout: Math.max(1, root.idleSeconds)
        respectInhibitors: false
        onIsIdleChanged: {
            root.idle = isIdle;
            if (isIdle) {
                if (root.level > 0) {
                    root.savedLevel = root.level;
                    root.setLevel(0);
                }
            } else if (root.savedLevel > 0) {
                if (root.level === 0)
                    root.setLevel(root.savedLevel);
                root.savedLevel = -1;
            }
            if (!isIdle)
                luxProc.running = true;
        }
    }

    // keys such as Fn+Space change it behind our back
    Timer {
        interval: 3000
        repeat: true
        running: root.available
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        refresh();
        luxProc.running = true;
    }
}
