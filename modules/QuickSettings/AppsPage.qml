import "../../components/"
import "../../config/"
import "../../services/" as Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var stackView
    property string query: ""
    readonly property var filteredApps: Services.Search.allApps.filter(app => {
        const term = query.trim().toLowerCase();
        return term === "" || app.name.toLowerCase().includes(term) || (app.description || "").toLowerCase().includes(term);
    }).sort((a, b) => a.name.localeCompare(b.name))

    function appIconSource(icon) {
        if (!icon)
            return "";
        if (icon.startsWith("file://") || icon.startsWith("/") || icon.startsWith("qrc:/"))
            return icon.startsWith("/") ? "file://" + icon : icon;
        return Quickshell.iconPath(icon, true);
    }

    Component.onCompleted: Qt.callLater(() => searchField.forceActiveFocus())

    implicitHeight: layout.implicitHeight + 32

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12

        PageHeader {
            Layout.fillWidth: true
            title: "All apps"
            subtitle: root.filteredApps.length + " installed applications"
            onBack: stackView.pop()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 24
            color: Appearance.surfaceColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                MaterialSymbol {
                    icon: "search"
                    font.pixelSize: 20
                    color: Appearance.mutedColor
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    onTextChanged: root.query = text
                    placeholderText: "Search apps"
                    placeholderTextColor: Appearance.mutedColor
                    color: Appearance.fgColor
                    selectionColor: Appearance.accentColor
                    selectedTextColor: Appearance.accentContrastColor
                    font.family: Appearance.fontFamily
                    font.pixelSize: 14
                    background: null
                    Accessible.name: "Search installed apps"

                    TapHandler {
                        onTapped: searchField.forceActiveFocus()
                    }
                }

                MaterialSymbol {
                    visible: root.query !== ""
                    icon: "close"
                    font.pixelSize: 18
                    color: Appearance.mutedColor
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchField.clear()
                    }
                }
            }
        }

        ListView {
            id: appList

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Math.max(contentHeight, 56), 7 * 59 - 3)
            model: root.filteredApps
            spacing: 3
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: appList.width
                height: 56
                topLeftRadius: index === 0 ? 20 : 6
                topRightRadius: index === 0 ? 20 : 6
                bottomLeftRadius: index === appList.count - 1 ? 20 : 6
                bottomRightRadius: index === appList.count - 1 ? 20 : 6
                color: appMouse.containsMouse ? Appearance.surfaceHighColor : Appearance.surfaceColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 16
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 18
                        color: Appearance.surfaceHighColor

                        Image {
                            id: desktopIcon
                            anchors.centerIn: parent
                            width: 25
                            height: 25
                            source: root.appIconSource(modelData.image)
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !desktopIcon.visible
                            icon: "apps"
                            font.pixelSize: 19
                            color: Appearance.fgColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            font.weight: Font.Medium
                            color: Appearance.fgColor
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: modelData.description || ""
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: Appearance.mutedColor
                        }
                    }

                    MaterialSymbol {
                        icon: "arrow_outward"
                        font.pixelSize: 17
                        color: Appearance.mutedColor
                    }
                }

                MouseArea {
                    id: appMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        modelData.execute();
                        WindowManager.quickSettingsVisible = false;
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.filteredApps.length === 0
            text: "No apps found"
            color: Appearance.mutedColor
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
