import Quickshell
import "modules/Bar"
import "modules/Search"
import "modules/QuickSettings"
import "modules/Workspaces"
import "modules/OSD"
import "modules/Settings"
import Quickshell.Hyprland

Scope {
    Bar {}
    QuickSettings {}
    Settings {}

    Search {}
    VolumeOsd {}
    Workspaces {}
}
