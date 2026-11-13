import Quickshell
import Quickshell.Hyprland
import QtQuick
import "modules/Bar"
import "modules/Clipboard"
import "modules/Dock"
import "modules/Idle"
import "modules/Notifications"
import "modules/OSD"
import "modules/QuickSettings"
import "modules/ScreenTools"
import "modules/Search"
import "modules/Settings"
import "modules/Workspaces"
import "services" as Services

Scope {
    Component.onCompleted: Services.Wallpaper.apply()

    Dock {
    }

    Idle {
    }

    Bar {
    }

    NotificationCenter {
    }

    QuickSettings {
    }

    Settings {
    }

    Search {
    }

    Clipboard {
    }

    ScreenTools {
    }

    VolumeOsd {
    }

    BrightnessOsd {
    }

    Workspaces {
    }

}
