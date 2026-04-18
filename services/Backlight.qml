import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property real percentage: 0
    property real _lastPercentage: -1
    property int _tempCurrent: 0

    signal changed()

    function setBrightness(value) {
        setBrightnessProc.exec(["/usr/bin/brightnessctl", "set", Math.round(value * 100) + "%"]);
    }

    Process {
        id: setBrightnessProc
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (!fetchProc.running)
                fetchProc.running = true;

        }
    }

    Process {
        id: fetchProc

        command: ["/usr/bin/brightnessctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                const current = parseInt(text.trim());
                if (!isNaN(current)) {
                    root._tempCurrent = current;
                    maxProc.running = true;
                }
            }
        }

    }

    Process {
        id: maxProc

        command: ["/usr/bin/brightnessctl", "max"]

        stdout: StdioCollector {
            onStreamFinished: {
                const max = parseInt(text.trim());
                if (!isNaN(max) && max > 0) {
                    const newPercentage = root._tempCurrent / max;
                    if (Math.abs(newPercentage - root._lastPercentage) > 0.005) {
                        root.percentage = newPercentage;
                        root._lastPercentage = newPercentage;
                        root.changed();
                    }
                }
            }
        }

    }

    Process {
        running: true
        command: ["/usr/bin/brightnessctl", "monitor"]

        stdout: SplitParser {
            onRead: {
                const m = data.match(/(\d+)%/);
                if (m) {
                    const np = parseInt(m[1]) / 100;
                    if (Math.abs(np - root._lastPercentage) > 0.005) {
                        root.percentage = np;
                        root._lastPercentage = np;
                        root.changed();
                    }
                }
            }
        }

    }

}
