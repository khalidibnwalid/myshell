import Quickshell
import "modules/Bar"
import "modules/Search"
import "modules/QuickSettings"
import "modules/Workspaces"
import "modules/OSD"
import Quickshell.Hyprland

Scope {
    Bar {}
    QuickSettings {}

    Search {}
    VolumeOsd {}
    Workspaces {}
}
