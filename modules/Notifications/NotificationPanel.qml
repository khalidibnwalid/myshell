import "../../components"
import "../../config"
import "../../services"
import QtQuick
import QtQuick.Layouts

// Card listing every pending notification, shown above the quick settings.
Rectangle {
    id: root

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

    RowLayout {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.pad

        PillButton {
            implicitHeight: 40
            text: "Do not disturb"
            toggled: NotificationService.dnd
            onClicked: NotificationService.dnd = !NotificationService.dnd
        }

        Item {
            Layout.fillWidth: true
        }

        PillButton {
            implicitHeight: 40
            text: "Clear all"
            onClicked: NotificationService.clearAll()
        }
    }
}
