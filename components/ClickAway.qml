import QtQuick

// Put it in a window: pressing anywhere takes the keyboard focus from the control that has it, so its outline goes.
// It watches the press without taking it, so buttons and text fields still get their click.
Item {
    id: root

    // what gets the focus (default: the window's content); give it the item that handles typing
    property Item target: null

    anchors.fill: parent
    z: 100000

    PointHandler {
        acceptedButtons: Qt.AllButtons
        onActiveChanged: {
            if (active && root.Window.window)
                (root.target ?? root.Window.window.contentItem).forceActiveFocus();
        }
    }
}
