import "../config/"
import QtQuick
import QtQuick.Layouts

// A titled group of rows (SettingRow, ListRow, …). The group rounds the outer
// corners of its first and last visible row, so rows can come and go freely.
ColumnLayout {
    id: root

    property string title
    default property alias rows: body.data
    property var watched: []
    // optional controls on the right of the title
    property alias actions: actionsRow.data

    function schedule() {
        // a row can change visibility while the page is being torn down
        if (typeof root.relayout === "function")
            Qt.callLater(root.relayout);
    }

    function relayout() {
        const shown = [];
        for (let i = 0; i < body.children.length; i++) {
            const child = body.children[i];
            // Repeaters and other helpers have no corners to set
            if (child.first === undefined || child.last === undefined)
                continue;
            if (watched.indexOf(child) < 0) {
                watched.push(child);
                child.visibleChanged.connect(root.schedule);
            }
            if (child.visible)
                shown.push(child);
        }
        for (let i = 0; i < shown.length; i++) {
            shown[i].first = i === 0;
            shown[i].last = i === shown.length - 1;
        }
    }

    Layout.fillWidth: true
    spacing: 8
    Component.onCompleted: relayout()
    Component.onDestruction: {
        // rows outliving the group must not call back into it
        for (const child of watched) {
            try {
                child.visibleChanged.disconnect(root.schedule);
            } catch (e) {}
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 4
        visible: root.title !== "" || actionsRow.children.length > 0
        spacing: 6

        StyledText {
            Layout.fillWidth: true
            text: root.title
            color: Appearance.mutedColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        RowLayout {
            id: actionsRow

            spacing: 4
        }
    }

    ColumnLayout {
        id: body

        Layout.fillWidth: true
        spacing: 3
        onChildrenChanged: root.schedule()
    }
}
