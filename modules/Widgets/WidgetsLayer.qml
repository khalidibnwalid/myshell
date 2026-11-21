import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Widgets on the desktop: a clock, sound waves, a calendar. They sit behind the windows (the
// Bottom layer) and let every click through. Edit mode (qs ipc call widgets edit) lifts them above
// everything so they can be dragged, resized, restyled, removed and added.
Scope {
    id: root

    readonly property bool editing: DesktopWidgets.editing
    readonly property bool wanted: Config.widgets.enabled && (DesktopWidgets.items.length > 0 || editing)

    // the ids of the widgets, as a model that only gains and loses rows: dragging one does not rebuild the others
    ListModel {
        id: ids
    }

    function syncIds() {
        const want = DesktopWidgets.items.map(i => i.id);
        for (let i = ids.count - 1; i >= 0; i--) {
            if (want.indexOf(ids.get(i).wid) < 0)
                ids.remove(i);
        }
        const have = [];
        for (let i = 0; i < ids.count; i++)
            have.push(ids.get(i).wid);
        for (const id of want) {
            if (have.indexOf(id) < 0)
                ids.append({
                    "wid": id
                });
        }
    }

    Connections {
        function onWidgetItemsChanged() {
            root.syncIds();
        }

        target: Config
    }

    Component.onCompleted: syncIds()

    // qs ipc call widgets edit | done | toggle | add clock|waves|calendar
    IpcHandler {
        function edit(): void {
            DesktopWidgets.editing = true;
        }

        function done(): void {
            DesktopWidgets.editing = false;
        }

        function toggle(): void {
            DesktopWidgets.editing = !DesktopWidgets.editing;
        }

        // opens the options of the first widget of a type (clock, waves, calendar)
        function options(type: string): void {
            const item = DesktopWidgets.items.find(i => i.type === type);
            if (!item)
                return;
            DesktopWidgets.editing = true;
            DesktopWidgets.optionsFor = item.id;
        }

        // how many fonts the options list offers, and whether one is in it: qs ipc call widgets fonts "Name"
        function fonts(name: string): string {
            return DesktopWidgets.fonts.length + " fonts" + (name !== "" ? (DesktopWidgets.fonts.indexOf(name) >= 0 ? ", has " + name : ", no " + name) : "");
        }

        // change one option of the first widget of a type: qs ipc call widgets set clock font "Lalezar"
        // (an empty value takes the option off, back to its default)
        function set(type: string, key: string, value: string): void {
            const item = DesktopWidgets.items.find(i => i.type === type);
            if (!item)
                return;
            const patch = {};
            patch[key] = value === "" ? null : value;
            DesktopWidgets.update(item.id, patch);
        }

        // switch the widgets on or off, like the Settings toggle: qs ipc call widgets enable false
        function enable(on: bool): void {
            Config.widgets.enabled = on;
        }

        function clear(): void {
            Config.setWidgetItems([]);
        }

        function add(type: string): void {
            DesktopWidgets.add(type);
        }

        target: "widgets"
    }

    GlobalShortcut {
        name: "widgets-edit"
        onPressed: DesktopWidgets.editing = !DesktopWidgets.editing
    }

    // leaving edit mode when the widgets are switched off
    Connections {
        function onEnabledChanged() {
            if (!Config.widgets.enabled)
                DesktopWidgets.editing = false;
        }

        target: Config.widgets
    }

    // the first screen only: one set of places for one screen
    LazyLoader {
        active: root.wanted

        PanelWindow {
            id: win

            screen: Quickshell.screens[0]

            readonly property HyprlandMonitor monitor: Hyprland.monitors.values.find(m => m.name === screen?.name) ?? null
            // the wallpaper is in front: nothing open on the workspace, or edit mode lifts the widgets above all
            readonly property bool desktopShown: root.editing || (monitor?.activeWorkspace?.toplevels?.values?.length ?? 0) === 0

            Binding {
                target: DesktopWidgets
                property: "desktopShown"
                value: win.desktopShown
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // full screen, whatever the bar and the dock reserve
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell-widgets"
            WlrLayershell.layer: root.editing ? WlrLayer.Overlay : WlrLayer.Bottom
            // editing takes the keyboard when it is asked for; the options panel (font search) takes all of it
            WlrLayershell.keyboardFocus: !root.editing ? WlrKeyboardFocus.None : DesktopWidgets.optionsFor !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
            // not editing: no part of the window takes a click; editing: all of it does
            mask: Region {
                item: root.editing ? area : null
            }

            FocusScope {
                id: area

                anchors.fill: parent
                focus: root.editing
                TypeToSearch {
                    id: ahead

                    onTyped: text => {
                        if (optionsLoader.item)
                            optionsLoader.item.typeInto(text);
                    }
                }

                Keys.onPressed: event => ahead.press(event)
                Keys.onEscapePressed: {
                    if (DesktopWidgets.optionsFor !== "")
                        DesktopWidgets.optionsFor = "";
                    else
                        DesktopWidgets.editing = false;
                }

                Repeater {
                    model: ids

                    WidgetFrame {
                        host: area
                    }
                }

                // the options of the widget whose tune button is on
                Loader {
                    id: optionsLoader

                    active: root.editing && DesktopWidgets.optionsFor !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 90
                    sourceComponent: WidgetOptions {
                        wid: DesktopWidgets.optionsFor
                        maxHeight: area.height - 120
                    }
                }

                // the tray of edit mode: add a widget, finish
                Rectangle {
                    id: panel

                    visible: root.editing
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 96
                    width: panelRow.implicitWidth + 32
                    height: panelRow.implicitHeight + 32
                    radius: 36
                    color: Qt.alpha(Appearance.bgColor, Math.max(0.35, Appearance.panelAlpha))
                    border.width: 1
                    border.color: Appearance.hairlineColor

                    // a click on the empty tray must not count as a click on the desktop
                    MouseArea {
                        anchors.fill: parent
                    }

                    RowLayout {
                        id: panelRow

                        anchors.centerIn: parent
                        spacing: 10

                        StyledText {
                            text: "Drag to move · wheel to resize"
                            color: Appearance.mutedColor
                            font.pixelSize: 13
                            Layout.rightMargin: 6
                        }

                        Repeater {
                            model: DesktopWidgets.types

                            PillButton {
                                required property var modelData

                                text: modelData.label
                                icon: modelData.icon
                                onClicked: DesktopWidgets.add(modelData.type)
                            }
                        }

                        PillButton {
                            text: "Done"
                            icon: "check"
                            toggled: true
                            onClicked: DesktopWidgets.editing = false
                        }
                    }
                }
            }
        }
    }
}
