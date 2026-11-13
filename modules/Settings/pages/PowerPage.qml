import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

SettingsPage {
    id: page

    readonly property var device: Battery.device
    readonly property bool hasBattery: !!device && device.isLaptopBattery
    // action waiting for its second click
    property string confirming: ""
    readonly property var sessionActions: [
        {
            "key": "lock",
            "icon": "lock",
            "title": "Lock",
            "description": "Lock the screen now",
            "confirm": false,
            "run": () => WindowManager.lockRequested()
        },
        {
            "key": "suspend",
            "icon": "bedtime",
            "title": "Suspend",
            "description": "Sleep and keep your session in memory",
            "confirm": false,
            "run": () => WindowManager.suspendComputer()
        },
        {
            "key": "logout",
            "icon": "logout",
            "title": "Log out",
            "description": "Close every app and end the Hyprland session",
            "confirm": true,
            "run": () => WindowManager.logOut()
        },
        {
            "key": "restart",
            "icon": "restart_alt",
            "title": "Restart",
            "description": "Reboot the computer",
            "confirm": true,
            "run": () => WindowManager.restartComputer()
        },
        {
            "key": "shutdown",
            "icon": "power_settings_new",
            "title": "Shut down",
            "description": "Power the computer off",
            "confirm": true,
            "run": () => WindowManager.shutdownComputer()
        }
    ]

    function duration(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
    }

    function batteryDetails() {
        if (!device)
            return "";
        if (device.state === UPowerDeviceState.Charging && device.timeToFull > 0)
            return "Charging · full in " + duration(device.timeToFull);
        if (device.state === UPowerDeviceState.Discharging && device.timeToEmpty > 0)
            return "On battery · " + duration(device.timeToEmpty) + " left";
        return Battery.stateString;
    }

    title: "Power"
    subtitle: hasBattery ? Math.round(Battery.percentage * 100) + "% · " + Battery.stateString : ""

    Timer {
        id: confirmTimer

        interval: 4000
        onTriggered: page.confirming = ""
    }

    SettingGroup {
        visible: page.hasBattery
        title: "Battery"

        SettingRow {
            icon: "battery_full"
            title: Math.round(Battery.percentage * 100) + "%"
            description: page.batteryDetails()

            Meter {
                implicitWidth: 220
                value: Battery.percentage
            }
        }

        SettingRow {
            visible: !!page.device && page.device.healthSupported
            icon: "favorite"
            title: "Battery health"
            description: "Capacity left compared with a new battery"

            StyledText {
                text: page.device ? Math.round(page.device.healthPercentage) + "%" : ""
                color: Appearance.mutedColor
            }
        }

        SettingRow {
            visible: !!page.device && Math.abs(page.device.changeRate) > 0.01
            icon: "electric_bolt"
            title: "Power draw"
            description: "How fast the battery is charging or draining"

            StyledText {
                text: page.device ? Math.abs(page.device.changeRate).toFixed(1) + " W" : ""
                color: Appearance.mutedColor
            }
        }
    }

    SettingGroup {
        title: "Power profile"

        Repeater {
            model: Battery.powerProfilesList

            delegate: ListRow {
                required property var modelData

                Layout.fillWidth: true
                icon: modelData.icon
                title: modelData.name
                subtitle: modelData.description
                active: Battery.activeProfile === modelData.key
                trailingIcon: active ? "check" : ""
                onClicked: Battery.setProfile(modelData.key)
            }
        }
    }

    SettingGroup {
        title: "Session"

        Repeater {
            model: page.sessionActions

            delegate: SettingRow {
                id: action

                required property var modelData
                readonly property bool armed: page.confirming === modelData.key

                icon: modelData.icon
                title: modelData.title
                description: armed ? "Click again to confirm" : modelData.description

                PillButton {
                    toggled: action.armed
                    text: action.armed ? "Confirm" : action.modelData.title
                    onClicked: {
                        if (action.modelData.confirm && !action.armed) {
                            page.confirming = action.modelData.key;
                            confirmTimer.restart();
                            return;
                        }
                        page.confirming = "";
                        action.modelData.run();
                    }
                }
            }
        }
    }
}
