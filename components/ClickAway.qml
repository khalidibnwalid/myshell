import QtQuick

// Put it in a window: pressing anywhere takes the keyboard focus from the control that has it, so its outline goes.
// It watches the press without taking it, so buttons and text fields still get their click.
Item {
    id: root

    anchors.fill: parent
    z: 100000

    PointHandler {
        acceptedButtons: Qt.AllButtons
        onActiveChanged: {
            if (active && root.Window.window)
                root.Window.window.contentItem.forceActiveFocus();
        }
    }
}
