import Quickshell
import Quickshell.Hyprland
import QtQuick
import "modules/Autocomplete"
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
    Component.onCompleted: {
        Services.Wallpaper.apply();
        // these two apply their saved settings on their own once created
        Services.NightLight.refresh();
        Services.Displays.applySaved();
    }

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

    MicOsd {
    }

    Suggestions {
    }

    StatusOsd {
    }

    Workspaces {
    }

}
