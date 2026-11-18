import QtQuick

// The keys of the Audio window.
Item {
    id: root

    property var window: null
    // the search box has the keyboard, so the keys that would type are left alone
    property bool typing: false

    Shortcut {
        sequence: "Space"
        enabled: !window.typing
        onActivated: Player.toggle()
    }

    Shortcut {
        sequence: "Left"
        enabled: !window.typing
        onActivated: Player.seek(Player.positionMs - 5000)
    }

    Shortcut {
        sequence: "Right"
        enabled: !window.typing
        onActivated: Player.seek(Player.positionMs + 5000)
    }

    Shortcut {
        sequence: "Up"
        enabled: !window.typing
        onActivated: Player.setVolume(Player.volume + 0.05)
    }

    Shortcut {
        sequence: "Down"
        enabled: !window.typing
        onActivated: Player.setVolume(Player.volume - 0.05)
    }

    Shortcut {
        sequence: "Ctrl+Right"
        onActivated: Player.next()
    }

    Shortcut {
        sequence: "Ctrl+Left"
        onActivated: Player.previous()
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: {
            if (!window.sidebarOpen)
                window.sidebarOpen = true;
            window.focusSearch();
        }
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: window.sidebarOpen = !window.sidebarOpen
    }

    Shortcut {
        sequence: "Ctrl+L"
        onActivated: window.togglePane("lyrics")
    }

    Shortcut {
        sequence: "Ctrl+J"
        onActivated: window.togglePane("queue")
    }

    Shortcut {
        sequence: "Ctrl+O"
        onActivated: window.openFiles()
    }

    Shortcut {
        sequence: "Ctrl+Shift+S"
        onActivated: Player.setShuffle(!Player.shuffle)
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: Player.cycleRepeat()
    }

    // Ctrl+1 to Ctrl+5 open the sections of the sidebar
    Repeater {
        model: window.sections

        Item {
            id: section

            required property var modelData
            required property int index

            Shortcut {
                sequence: "Ctrl+" + (section.index + 1)
                onActivated: window.go(section.modelData.id)
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: window.back()
    }
}
