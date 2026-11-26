pragma Singleton

import "../config"
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// One notification server for the whole shell.
// - `list`: every notification still alive (newest first), shown in the panel
// - `popups`: the transient toasts, hidden after a timeout but kept in `list`
Singleton {
    id: root

    // kept in config.json so it survives a restart
    property bool dnd: Config.notifications.dnd
    onDndChanged: {
        if (Config.notifications.dnd !== dnd)
            Config.notifications.dnd = dnd;
    }

    Connections {
        function onDndChanged() {
            root.dnd = Config.notifications.dnd;
        }

        target: Config.notifications
    }

    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length
    readonly property alias popups: popupModel
    // notification id -> arrival time (ms)
    property var arrivals: ({})

    function find(id) {
        return server.trackedNotifications.values.find(n => n.id === id) || null;
    }

    // A toast is first marked as leaving, so it can slide out, and removed a moment later
    function hidePopup(id) {
        for (let i = 0; i < popupModel.count; i++) {
            if (popupModel.get(i).nid === id) {
                if (!popupModel.get(i).leaving) {
                    popupModel.setProperty(i, "leaving", true);
                    purge.restart();
                }
                break;
            }
        }
    }

    // the toasts still on screen and not on their way out
    function shownPopups() {
        let n = 0;
        for (let i = 0; i < popupModel.count; i++)
            if (!popupModel.get(i).leaving)
                n++;
        return n;
    }

    // removes the toasts that have finished sliding out
    Timer {
        id: purge

        interval: 280
        onTriggered: {
            for (let i = popupModel.count - 1; i >= 0; i--)
                if (popupModel.get(i).leaving)
                    popupModel.remove(i);
        }
    }

    function dismiss(id) {
        hidePopup(id);
        const n = find(id);
        if (n)
            n.dismiss();
    }

    function clearAll() {
        popupModel.clear();
        server.trackedNotifications.values.slice().forEach(n => n.dismiss());
    }

    // "now", "2m", "3h", "4d" — pass the current date so bindings stay live
    function age(id, now) {
        const t = arrivals[id];
        if (!t)
            return "";
        const s = Math.max(0, Math.floor((now.getTime() - t) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    function iconSource(icon) {
        if (!icon)
            return "";
        // a file sent as the image (notify-send -i /path/shot.png) comes as image://icon//path: the icon
        // provider hands back an icon-sized copy that looks blurred when shown larger, so read the file itself
        if (icon.startsWith("image://icon//"))
            return "file://" + icon.substring("image://icon/".length);
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.includes("://"))
            return icon;
        return Icons.path(icon, true);
    }

    ListModel {
        id: popupModel
    }

    NotificationServer {
        id: server

        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: notification => {
            notification.tracked = true;
            const id = notification.id;
            root.arrivals[id] = Date.now();
            notification.closed.connect(() => {
                root.hidePopup(id);
                delete root.arrivals[id];
            });
            // a replaced notification reuses its id: refresh the toast
            root.hidePopup(id);
            if (!root.dnd)
                popupModel.append({
                    "nid": id,
                    "summary": notification.summary,
                    "body": notification.body,
                    "appName": notification.appName,
                    "appIcon": notification.appIcon,
                    "image": notification.image,
                    "timeout": notification.expireTimeout,
                    "leaving": false
                });
            // at most three toasts at a time: the oldest leaves the screen (it stays in the panel),
            // so the stack never runs past the window and gets cut off
            for (let i = 0; i < popupModel.count && root.shownPopups() > 3; i++)
                if (!popupModel.get(i).leaving)
                    root.hidePopup(popupModel.get(i).nid);
        }
    }
}
