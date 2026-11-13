import "../../components/"
import "../../config/"
import QtQuick
import QtQuick.Layouts
import Quickshell

// Entries of a tray menu. Sub-menus expand in place (this file loads itself for them).
ColumnLayout {
    id: root

    property var menu // QsMenuHandle

    signal closeRequested()

    spacing: 2

    QsMenuOpener {
        id: opener

        menu: root.menu
    }

    Repeater {
        model: opener.children

        delegate: ColumnLayout {
            id: entry

            required property var modelData
            property bool expanded: false
            readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None
            readonly property bool checked: modelData.checkState === Qt.Checked

            Layout.fillWidth: true
            spacing: 2

            // separator
            Rectangle {
                visible: entry.modelData.isSeparator
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                implicitHeight: 1
                color: Appearance.outlineColor
            }

            // entry
            Rectangle {
                visible: !entry.modelData.isSeparator
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 12
                color: rowArea.containsMouse && entry.modelData.enabled ? Appearance.surfaceHighColor : "transparent"
                opacity: entry.modelData.enabled ? 1 : 0.4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    MaterialSymbol {
                        visible: entry.checkable
                        icon: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? (entry.checked ? "radio_button_checked" : "radio_button_unchecked") : (entry.checked ? "check_box" : "check_box_outline_blank")
                        fill: entry.checked ? 1 : 0
                        font.pixelSize: 17
                        color: entry.checked ? Appearance.accentColor : Appearance.mutedColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: entry.modelData.text
                        elide: Text.ElideRight
                        font.pixelSize: 13
                    }

                    MaterialSymbol {
                        visible: entry.modelData.hasChildren
                        icon: "chevron_right"
                        font.pixelSize: 18
                        color: Appearance.mutedColor
                        rotation: entry.expanded ? 90 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Appearance.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: entry.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!entry.modelData.enabled)
                            return;
                        if (entry.modelData.hasChildren) {
                            entry.expanded = !entry.expanded;
                        } else {
                            entry.modelData.triggered();
                            root.closeRequested();
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animFast
                    }
                }
            }

            // sub-menu
            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                active: entry.expanded
                visible: active
                source: "TrayMenuList.qml"
                onLoaded: {
                    item.menu = Qt.binding(() => entry.modelData);
                    item.closeRequested.connect(root.closeRequested);
                }
            }
        }
    }
}
