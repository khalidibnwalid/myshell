pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Scope {
    id: root

    readonly property var device: UPower.displayDevice
    
    // Robust properties with safe defaults to prevent NaN or binding errors
    property real percentage: device ? device.percentage : 0
    property var state: device ? device.state : UPowerDeviceState.Unknown
    property string stateString: device ? UPowerDeviceState.toString(device.state) : "Unknown"

    property string iconName: {
        if (!device) return "battery_unknown";

        if (root.state === UPowerDeviceState.Charging || root.state === UPowerDeviceState.FullyCharged || root.state === UPowerDeviceState.PendingCharge) {
            return "battery_android_bolt";
        }

        if (percentage > 0.10) {
            //set the fill of MaterialSymbol to percentage (real)
            return "battery_android_0";
        } else {
            return "battery_android_frame_alert";
        }
    }

    property var powerProfiles: PowerProfiles
    property var activeProfile: powerProfiles.profile
    // ref: https://quickshell.org/docs/master/types/Quickshell.Services.UPower/PowerProfile/
    property list<var> powerProfilesList: [
        {
            name: "Performance",
            description: "This profile will maximize performance at the cost of power consumption.",
            icon: "speed",
            key: PowerProfile.Performance
        },
        {
            name: "Balanced",
            description: "This profile will balance performance and power consumption.",
            icon: "balance",
            key: PowerProfile.Balanced
        },
        {
            name: "Power Saver",
            description: "This profile will minimize power consumption at the cost of performance.",
            icon: "energy_savings_leaf",
            key: PowerProfile.PowerSaver
        }
    ]
    property string activeProfileIcon: profileIcon(activeProfile)

    function profileIcon(name) {
        switch (name) {
        case (PowerProfile.Performance):
            return "speed";
        case (PowerProfile.Balanced):
            return "balance";
        case (PowerProfile.PowerSaver):
            return "energy_savings_leaf";
        default:
            return "battery_android_question";
        }
    }

    function setProfile(profile) {
        powerProfiles.profile = profile;
    }
}
