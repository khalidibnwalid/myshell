import QtQuick

// Typing a character while no text field has the keyboard goes to the search box. Put it in a window, let the
// lists leave printable keys unaccepted so they bubble up, and in an ancestor of the lists:
//   Keys.onPressed: event => ahead.press(event)
// Space, Enter and anything with Ctrl, Alt or Meta are not typing: they stay shortcuts.
Item {
    id: root

    signal typed(string text)

    function press(event) {
        const t = event.text;
        if (t.length !== 1 || t.charCodeAt(0) < 32 || t === " " || t.charCodeAt(0) === 127)
            return;
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        event.accepted = true;
        typed(t);
    }
}
