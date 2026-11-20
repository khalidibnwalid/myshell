import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page

    readonly property int pauseLeft: WindowManager.idlePauseRemainingSeconds

    function minutes(list) {
        return list.map(m => ({
            "label": m === 0 ? "Never" : (m < 60 ? m + " min" : (m / 60) + " h"),
            "value": m
        }));
    }

    title: "Lock & idle"
    subtitle: Config.idle.enabled ? "Locks after " + Config.idle.lockAfterMinutes + " min without input" : "Auto-lock is off"

    SettingGroup {
        title: "Auto-lock"

        SettingRow {
            icon: "lock_clock"
            title: "Lock when idle"
            description: "Lock the session after a time without keyboard or mouse input"

            ToggleSwitch {
                checked: Config.idle.enabled
                onToggled: on => Config.idle.enabled = on
            }
        }

        SettingRow {
            visible: Config.idle.enabled
            title: "Lock after"
            description: "Time without input before the session locks"

            Dropdown {
                model: page.minutes([1, 2, 3, 5, 10, 15, 30, 60])
                value: Config.idle.lockAfterMinutes
                placeholder: Config.idle.lockAfterMinutes + " min"
                popupWidth: 160
                onSelected: m => Config.idle.lockAfterMinutes = m
            }
        }

        SettingRow {
            visible: Config.idle.enabled
            title: "Turn displays off after"
            description: Config.idle.screenOffAfterMinutes > 0 && Config.idle.screenOffAfterMinutes <= Config.idle.lockAfterMinutes ? "Has no effect until it is longer than the lock time" : "Counted from the last input; the session is already locked by then"

            Dropdown {
                model: page.minutes([0, 5, 10, 15, 30, 60, 120])
                value: Config.idle.screenOffAfterMinutes
                placeholder: Config.idle.screenOffAfterMinutes + " min"
                popupWidth: 160
                onSelected: m => Config.idle.screenOffAfterMinutes = m
            }
        }

        SettingRow {
            visible: Config.idle.enabled
            icon: "bedtime_off"
            title: "Pause auto-lock"
            description: page.pauseLeft > 0 ? "Paused for another " + Math.ceil(page.pauseLeft / 60) + " min" : "Keep the session unlocked for one hour, e.g. while watching something"

            PillButton {
                toggled: page.pauseLeft > 0
                text: page.pauseLeft > 0 ? "Resume" : "Pause 1 h"
                onClicked: WindowManager.toggleIdlePause()
            }
        }
    }

    SettingGroup {
        title: "Administrator prompts"

        SettingRow {
            icon: "admin_panel_settings"
            title: "Use the shell's own password prompt"
            description: Config.polkit.enabled ? "Apps that need administrator rights ask for your password in the shell's look" : "Off: the system's prompt is used, so another polkit agent must be running"

            ToggleSwitch {
                checked: Config.polkit.enabled
                onToggled: on => Config.polkit.enabled = on
            }
        }
    }

    SettingGroup {
        title: "Lock screen"

        SettingRow {
            icon: "lock"
            title: "Lock now"
            description: "Also on Super + L. The lock screen uses your wallpaper and login password."

            PillButton {
                text: "Lock"
                onClicked: WindowManager.lockRequested()
            }
        }
    }
}
