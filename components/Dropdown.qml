import "../config/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Pill that opens a list of choices. Needs to live inside an ApplicationWindow.
// model: strings, or { label, value, description } objects
Rectangle {
    id: root

    property var model: []
    property var value
    property string placeholder: "Choose"
    // fixed caption instead of the current choice (for "Add…" buttons)
    property string caption
    property string icon
    property bool searchable: false
    property int popupWidth: 260
    property string query: ""
    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return model;
        return model.filter(item => labelOf(item).toLowerCase().includes(q));
    }
    readonly property string currentLabel: {
        for (const item of model) {
            if (valueOf(item) === value)
                return labelOf(item);
        }
        return "";
    }

    signal selected(var value)

    function isObject(item) {
        return item !== null && typeof item === "object";
    }

    function labelOf(item) {
        return isObject(item) ? String(item.label) : String(item);
    }

    function valueOf(item) {
        return isObject(item) ? item.value : item;
    }

    implicitHeight: 36
    implicitWidth: Math.min(260, content.implicitWidth + 28)
    radius: height / 2
    color: area.containsMouse || popup.opened ? Appearance.surfaceHighColor : Appearance.surfaceColor
    opacity: enabled ? 1 : 0.45

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 6

        MaterialSymbol {
            visible: root.icon !== ""
            icon: root.icon
            font.pixelSize: 18
            color: Appearance.fgColor
        }

        StyledText {
            Layout.fillWidth: true
            text: root.caption !== "" ? root.caption : (root.currentLabel !== "" ? root.currentLabel : root.placeholder)
            elide: Text.ElideRight
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        MaterialSymbol {
            icon: "keyboard_arrow_down"
            font.pixelSize: 18
            color: Appearance.mutedColor
            rotation: popup.opened ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Appearance.animFast
                }
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.opened ? popup.close() : popup.open()
    }

    Popup {
        id: popup

        x: root.width - width
        y: root.height + 6
        width: Math.max(root.width, root.popupWidth)
        padding: 6
        margins: 8
        onOpened: {
            root.query = "";
            if (root.searchable) {
                search.clear();
                search.focusInput();
            }
        }

        background: Rectangle {
            radius: 20
            color: Qt.tint(Appearance.bgColor, Qt.alpha(Appearance.fgColor, 0.1))
            border.width: 1
            border.color: Appearance.outlineColor
        }

        contentItem: ColumnLayout {
            spacing: 6

            FieldInput {
                id: search

                Layout.fillWidth: true
                visible: root.searchable
                icon: "search"
                placeholder: "Search"
                onEdited: text => root.query = text
                onAccepted: {
                    if (root.filtered.length > 0) {
                        root.selected(root.valueOf(root.filtered[0]));
                        popup.close();
                    }
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 264)
                model: root.filtered
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                }

                delegate: Rectangle {
                    id: option

                    required property var modelData
                    readonly property bool current: root.valueOf(modelData) === root.value && root.caption === ""

                    width: list.width
                    height: 38
                    radius: 14
                    color: optionArea.containsMouse ? Appearance.surfaceHighColor : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            text: root.labelOf(option.modelData)
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            color: option.current ? Appearance.accentColor : Appearance.fgColor
                        }

                        StyledText {
                            visible: text !== ""
                            text: root.isObject(option.modelData) && option.modelData.description ? option.modelData.description : ""
                            font.pixelSize: 12
                            color: Appearance.mutedColor
                        }

                        MaterialSymbol {
                            visible: option.current
                            icon: "check"
                            font.pixelSize: 16
                            color: Appearance.accentColor
                        }
                    }

                    MouseArea {
                        id: optionArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selected(root.valueOf(option.modelData));
                            popup.close();
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.margins: 10
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: "Nothing matches"
                color: Appearance.mutedColor
                font.pixelSize: 13
            }
        }
    }
}
