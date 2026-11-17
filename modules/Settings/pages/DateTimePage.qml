import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page

    title: "Date, time & region"
    subtitle: Time.format(Config.bar.clock24h ? "dddd d MMMM yyyy · HH:mm" : "dddd d MMMM yyyy · hh:mm AP") + (Region.timezone !== "" ? " · " + Region.timezone : "")
    Component.onCompleted: Region.refresh()

    SettingGroup {
        title: "Date & time"

        SettingRow {
            icon: "public"
            title: "Time zone"
            description: "Asks for administrator rights"

            Dropdown {
                model: Region.timezones
                value: Region.timezone
                searchable: true
                popupWidth: 320
                onSelected: v => Region.setTimezone(v)
            }
        }

        SettingRow {
            icon: "sync"
            title: "Set the time automatically"
            description: !Region.canNtp ? "No time service is installed (try systemd-timesyncd or chrony)" : (Region.ntp ? (Region.synced ? "Synchronised with the internet" : "Waiting for the internet") : "Off: the clock is set by hand")

            ToggleSwitch {
                enabled: Region.canNtp && !Region.busy
                checked: Region.ntp
                onToggled: on => Region.setNtp(on)
            }
        }

        SettingRow {
            visible: !Region.ntp
            icon: "edit_calendar"
            title: "Set the time by hand"
            description: "Year-month-day hours:minutes, then Enter"

            FieldInput {
                value: Time.format("yyyy-MM-dd HH:mm")
                placeholder: "2026-11-17 14:30"
                onCommitted: text => Region.setTime(text)
            }
        }

        SettingRow {
            icon: "schedule"
            title: "24-hour clock"
            description: "In the bar, quick settings and on the lock screen · now " + Time.format(Config.bar.clock24h ? "HH:mm" : "hh:mm AP")

            ToggleSwitch {
                checked: Config.bar.clock24h
                onToggled: on => Config.bar.clock24h = on
            }
        }
    }

    SettingGroup {
        title: "Language & formats"

        SettingRow {
            icon: "translate"
            title: "Language"
            description: "The language of apps that translate themselves · takes effect after you sign in again"

            Dropdown {
                model: Region.locales
                value: Region.language
                searchable: true
                popupWidth: 320
                onSelected: v => Region.setLanguage(v)
            }
        }

        SettingRow {
            icon: "event"
            title: "Formats"
            description: "Dates, numbers, money, paper size and units · " + Qt.locale().name

            Dropdown {
                model: Region.locales
                value: Region.formats
                searchable: true
                popupWidth: 320
                onSelected: v => Region.setFormats(v)
            }
        }

        SettingRow {
            visible: Region.locales.length <= 2
            icon: "info"
            title: "Only a few languages are installed"
            description: "Uncomment more in /etc/locale.gen and run: sudo locale-gen"
        }
    }
}
