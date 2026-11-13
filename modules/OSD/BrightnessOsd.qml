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
        icon: backlight.percentage < 0.35 ? "brightness_low" : (backlight.percentage < 0.7 ? "brightness_medium" : "brightness_high")
        offset: 72
    }
}
