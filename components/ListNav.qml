import QtQuick

// The keys of a list or grid that has the keyboard focus: Home, End and the page keys, Enter, and a way back to
// what is above the first row. The arrows are the view's own (keyNavigationEnabled); this only takes them (and
// Enter) from the shortcuts of the window, which would act first. Use it in the view:
//   Keys.onShortcutOverride: event => nav.override(event)
//   Keys.onPressed: event => nav.press(event)
Item {
    id: root

    property Item view: null
    property real rowHeight: 60
    // a grid also uses Left and Right
    property bool horizontal: false

    signal activated
    signal topReached

    function override(event) {
        const keys = [Qt.Key_Up, Qt.Key_Down, Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Home, Qt.Key_End, Qt.Key_Return, Qt.Key_Enter];
        if (horizontal)
            keys.push(Qt.Key_Left, Qt.Key_Right);
        if (keys.indexOf(event.key) >= 0)
            event.accepted = true;
    }

    function press(event) {
        if (!view)
            return;
        const columns = view.cellWidth !== undefined && view.cellWidth > 0 ? Math.max(1, Math.floor(view.width / view.cellWidth)) : 1;
        const rowSize = view.cellHeight !== undefined && view.cellHeight > 0 ? view.cellHeight : rowHeight;
        const page = Math.max(1, Math.floor(view.height / rowSize)) * columns;
        let to = -1;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (view.currentIndex >= 0)
                activated();
            event.accepted = true;
            return;
        case Qt.Key_Up:
            if (view.currentIndex < columns) {
                topReached();
                event.accepted = true;
            }
            return;
        case Qt.Key_Home:
            to = 0;
            break;
        case Qt.Key_End:
            to = view.count - 1;
            break;
        case Qt.Key_PageUp:
            to = Math.max(0, view.currentIndex - page);
            break;
        case Qt.Key_PageDown:
            to = Math.min(view.count - 1, view.currentIndex + page);
            break;
        default:
            return;
        }
        if (to >= 0) {
            view.currentIndex = to;
            view.positionViewAtIndex(to, ListView.Contain);
        }
        event.accepted = true;
    }
}
