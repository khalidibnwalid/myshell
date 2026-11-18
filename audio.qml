import QtQuick
import Quickshell
import "apps/Audio"

// Audio runs as a program of its own: `qs -p audio.qml`. The main shell starts it when you open Audio
// (apps/Audio/scripts/ctl.sh) and it quits by itself once the window is closed and nothing plays, so it
// is not running when it is not used, and a reload of the main shell does not stop the sound.
// It sits at the top of the config so it can use components/, config/ and services/ like the shell does.
ShellRoot {
    AudioProgram {
    }
}
