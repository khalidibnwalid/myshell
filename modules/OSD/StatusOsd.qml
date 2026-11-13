import "../../config/"
import "../../services/"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// One message pill for state changes that have no level to show:
// microphone and screen sharing in use, keyboard layout, charger,
// power profile, do not disturb. Every one is event-driven; nothing is polled.
Scope {
    id: root

    property bool shown: false
    property string icon
    property string title
    property string detail
    property bool highlighted: true

    function show(icon, title, detail, highlighted) {
        // nothing at startup, while every service reports its first value
        if (startup.running)
            return;
        root.icon = icon;
        root.title = title;
        root.detail = detail || "";
        root.highlighted = highlighted !== false;
        root.shown = true;
        hideTimer.restart();
    }

    Timer {
        id: startup

        interval: 2500
        running: true
    }

    Timer {
        id: hideTimer

        interval: 1400
        onTriggered: root.shown = false
    }

    // --- keyboard layout: Hyprland announces every switch ---
    Connections {
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            const name = event.data.substring(event.data.indexOf(",") + 1);
            // the same event also fires when a keyboard is plugged in
            if (name === root.lastLayout)
                return;
            const first = root.lastLayout === "";
            root.lastLayout = name;
            if (!first)
                root.show("keyboard", Keyboard.parseLayout(name), name);
        }

        target: Hyprland
    }

    property string lastLayout: Keyboard.fullLayoutName

    // --- microphone: an application starts or stops recording ---
    // (level meters such as pavucontrol's are not recordings)
    readonly property var recorders: Pipewire.nodes.values.filter(node => node.isStream && node.audio && !node.isSink && !/peak detect|pavucontrol/i.test((node.properties?.["media.name"] || "") + " " + (node.properties?.["application.name"] || "")))
    readonly property int recorderCount: recorders.length
    property int lastRecorderCount: 0

    onRecorderCountChanged: {
        if (recorderCount > lastRecorderCount) {
            const node = recorders[recorders.length - 1];
            root.show("mic", "Microphone on", node.properties?.["application.name"] || node.description || node.name || "");
        } else if (recorderCount === 0) {
            root.show("mic_off", "Microphone off", "", false);
        }
        lastRecorderCount = recorderCount;
    }

    PwObjectTracker {
        objects: root.recorders
    }

    // --- screen sharing: Hyprland reports when a screencast starts or stops ---
    Connections {
        function onRawEvent(event) {
            if (event.name !== "screencast")
                return;
            const on = event.data.split(",")[0] === "1";
            root.show(on ? "screen_share" : "stop_screen_share", on ? "Screen sharing on" : "Screen sharing off", "", on);
        }

        target: Hyprland
    }

    // --- charger plugged in or pulled out, power profile ---
    Connections {
        function onStateChanged() {
            const percent = Math.round(Battery.percentage * 100) + "%";
            if (Battery.state === UPowerDeviceState.Charging)
                root.show(Battery.iconName, "Charging", percent);
            else if (Battery.state === UPowerDeviceState.Discharging)
                root.show(Battery.iconName, "On battery", percent, false);
            else if (Battery.state === UPowerDeviceState.FullyCharged)
                root.show(Battery.iconName, "Fully charged", "");
        }

        function onActiveProfileChanged() {
            const profile = Battery.powerProfilesList.find(p => p.key === Battery.activeProfile);
            if (profile)
                root.show(profile.icon, profile.name, "Power profile");
        }

        target: Battery
    }

    // --- do not disturb ---
    Connections {
        function onDndChanged() {
            root.show(NotificationService.dnd ? "do_not_disturb_on" : "notifications", "Do not disturb", NotificationService.dnd ? "On" : "Off", NotificationService.dnd);
        }

        target: NotificationService
    }

    OsdToast {
        shown: root.shown
        icon: root.icon
        title: root.title
        detail: root.detail
        highlighted: root.highlighted
    }
}
