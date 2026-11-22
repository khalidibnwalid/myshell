import "../../services"
import QtQuick
import Quickshell
import Quickshell.Wayland

// One black, click-through layer per screen whose opacity is the dim chosen for it in Settings.
// A screen at 100% has no window at all.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            readonly property real dim: 1 - ScreenDim.levelOf(modelData.name) / 100

            screen: modelData
            visible: dim > 0
            color: Qt.rgba(0, 0, 0, dim)
            exclusionMode: ExclusionMode.Ignore
            // clicks and the pointer pass through
            mask: Region {}
            // its own namespace: the blur rule for "quickshell" must not apply to it
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-dim"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
        }
    }
}
