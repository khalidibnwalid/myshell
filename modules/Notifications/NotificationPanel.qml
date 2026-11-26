import "../../components"
import "../../config"
import "../../services"
import QtQuick
import QtQuick.Layouts

// Card listing every pending notification, shown above the quick settings.
Rectangle {
    id: root

    Audio {
        id: audio
    }

    property real maxHeight: 600
    // outer radius (36) = inner radius (20) + padding (16), same as the quick settings card
    readonly property int pad: 16
    readonly property int gap: 12
    readonly property real listMaxHeight: maxHeight - footer.implicitHeight - pad * 2 - gap

    implicitWidth: 364
    implicitHeight: Math.min(list.contentHeight, listMaxHeight) + footer.implicitHeight + pad * 2 + gap
    radius: 36
    color: Appearance.panelColor
    border.width: 1
    border.color: Appearance.hairlineColor

    ListView {
        id: list

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.pad
        height: Math.min(contentHeight, root.listMaxHeight)
        model: NotificationService.list
        spacing: 3
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: NotificationItem {
            required property var modelData
            required property int index

            width: list.width
            inPanel: true
            cornerRadius: 20
            first: index === 0
            last: index === list.count - 1
            notification: modelData
            summary: modelData?.summary || modelData?.appName || ""
            body: modelData?.body ?? ""
            appName: modelData?.appName ?? ""
            appIcon: modelData?.appIcon ?? ""
            image: modelData?.image ?? ""
            meta: modelData ? NotificationService.age(modelData.id, Time.date) : ""
            onBodyClicked: expanded = !expanded
            onCloseRequested: NotificationService.dismiss(modelData.id)
        }
    }

    Timer {
        id: clearTimer

        onTriggered: NotificationService.clearAll()
    }

    RowLayout {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.pad
        spacing: 6

        IconButton {
            size: 40
            iconSize: 20
            icon: NotificationService.dnd ? "do_not_disturb_on" : "notifications"
            toggled: NotificationService.dnd
            Accessible.name: "Do not disturb"
            onClicked: NotificationService.dnd = !NotificationService.dnd
        }

        IconButton {
            size: 40
            iconSize: 20
            icon: audio.mute || audio.volume === 0 ? "volume_off" : "volume_up"
            toggled: audio.mute
            Accessible.name: audio.mute ? "Unmute" : "Mute"
            onClicked: audio.setMute(!audio.mute)
        }

        PillButton {
            implicitHeight: 40
            icon: "keyboard"
            text: Keyboard.layout
            onClicked: Keyboard.nextLayout()
        }

        Item {
            Layout.fillWidth: true
        }

        PillButton {
            implicitHeight: 40
            text: "Clear all"
            // every notification slides out to the left, one after the other, then the list is emptied
            onClicked: {
                if (clearTimer.running)
                    return;
                let shown = 0;
                for (let i = 0; i < list.count; i++) {
                    const item = list.itemAtIndex(i);
                    if (item)
                        item.swipeAway(shown++ * 45, true);
                }
                if (shown === 0) {
                    NotificationService.clearAll();
                    return;
                }
                clearTimer.interval = (shown - 1) * 45 + Appearance.animNormal + 30;
                clearTimer.start();
            }
        }
    }
}
