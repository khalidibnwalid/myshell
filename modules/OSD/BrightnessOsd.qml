import "../../services/"
import QtQuick
import Quickshell

Scope {
    id: root

    property bool shouldShowOsd: false

    Backlight {
        id: backlight

        // Direct signal handler is most reliable
        onChanged: {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer

        interval: 1200
        onTriggered: root.shouldShowOsd = false
    }

    Osd {
        shown: root.shouldShowOsd
        value: backlight.percentage
        // same icon as the brightness slider in quick settings
        icon: "light_mode"
        offset: 82
    }
}
