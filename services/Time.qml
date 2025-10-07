pragma Singleton
import Quickshell

Singleton {

    readonly property alias clock: clock
    readonly property date date: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function format(fmt) {
        return Qt.formatDateTime(clock.date, fmt);
    }
}
