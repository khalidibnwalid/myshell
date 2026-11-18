import Quickshell
import Quickshell.Hyprland
import QtQuick
import "modules/Autocomplete"
import "modules/Bar"
import "modules/Clipboard"
import "modules/Dock"
import "modules/Idle"
import "apps/Audio"
import "apps/Notepad"
import "apps/Processes"
import "apps/Timer"
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
        // reads the Hyprland options and keeps the window borders on the accent colour
        Services.HyprSettings.refresh();
        // the icons and desktop entries of the Settings window and of Notepad
        Quickshell.execDetached([Quickshell.shellDir + "/scripts/install-app-icons.sh", Quickshell.shellDir]);
        // the keyboard light's switch-off when idle
        Services.KeyboardLight.refresh();
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

    Notepad {
    }

    ProcessManager {
    }

    TimerApp {
    }

    AudioApp {
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
