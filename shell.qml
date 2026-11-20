import Quickshell
import Quickshell.Hyprland
import QtQml
import QtQuick
import "modules/Autocomplete"
import "modules/Bar"
import "modules/Clipboard"
import "modules/Dock"
import "modules/FileChooser"
import "modules/Idle"
import "apps/Audio"
import "apps/Notepad"
import "apps/Paint"
import "apps/Processes"
import "apps/Timer"
import "modules/Notifications"
import "modules/Polkit"
import "modules/OSD"
import "modules/QuickSettings"
import "modules/ScreenTools"
import "modules/Search"
import "modules/Settings"
import "modules/Workspaces"
import "services" as Services
import "config"

Scope {
    Component.onCompleted: {
        Services.Wallpaper.apply();
        // these two apply their saved settings on their own once created
        Services.NightLight.refresh();
        Services.Displays.applySaved();
        // reads the Hyprland options and keeps the window borders on the accent colour
        Services.HyprSettings.refresh();
        // finds the apps (apps/*/app.json), then installs the icons and desktop entries of Settings, Notepad and them
        Services.Apps.refresh();
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

    // The other apps are loaded from their app.json (see services/Apps.qml). One that is switched off is
    // not loaded, and is told to stop what it runs without a window when it is taken away. Each app folder is
    // imported above only so that its files see each other; nothing else names an app.
    Instantiator {
        model: Services.Apps.enabled

        delegate: LazyLoader {
            required property var modelData

            // relative to this file, so the app sees the same singletons as everything else
            source: Qt.resolvedUrl("apps/" + modelData.dir.split("/").pop() + "/" + modelData.entry)
            active: true
        }

        onObjectRemoved: (index, object) => Services.Apps.released(object.modelData, object.item)
    }

    FileChooser {
    }

    // the polkit agent: off, the prompt is not loaded and another agent may register
    LazyLoader {
        active: Config.polkit.enabled

        PolkitDialog {
        }
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
