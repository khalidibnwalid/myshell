import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

// One Bluetooth device: click for its primary action, or open its action menu.
Rectangle {
    id: root

    required property var device
    property Item menuHost: null
    property bool first: false
    property bool last: false
    readonly property bool active: device.connected
    readonly property bool busy: Bluetooth.isBusy(device)
    readonly property bool menuOpen: Bluetooth.contextMenuAddress === device.address
    readonly property color contentColor: active ? Appearance.accentContrastColor : Appearance.fgColor
    readonly property int outerTop: first ? 20 : 6
    readonly property int outerBottom: last ? 20 : 6

    function deviceIcon(name) {
        const icon = (name || "").toLowerCase();
        if (icon.includes("headphone") || icon.includes("headset")) return "headphones";
        if (icon.includes("audio") || icon.includes("speaker")) return "speaker";
        if (icon.includes("microphone")) return "mic";
        if (icon.includes("keyboard")) return "keyboard";
        if (icon.includes("mouse")) return "mouse";
        if (icon.includes("gaming") || icon.includes("joystick")) return "sports_esports";
        if (icon.includes("printer")) return "print";
        if (icon.includes("phone")) return "smartphone";
        if (icon.includes("computer")) return "computer";
        if (icon.includes("video") || icon.includes("display") || icon.includes("tv")) return "tv";
        if (icon.includes("watch")) return "watch";
        return "bluetooth";
    }

    implicitWidth: 360
    implicitHeight: 56
    topLeftRadius: outerTop
    topRightRadius: outerTop
    bottomLeftRadius: outerBottom
    bottomRightRadius: outerBottom
    color: Appearance.surfaceColor
    z: menuOpen ? 10 : 0

    Rectangle {
        id: header

        anchors.fill: parent
        radius: root.active ? root.outerTop : 0
        topLeftRadius: root.outerTop
        topRightRadius: root.outerTop
        bottomLeftRadius: root.outerBottom
        bottomRightRadius: root.outerBottom
        color: root.active ? (rowArea.containsMouse ? Appearance.accentColorLight : Appearance.accentColor) : (rowArea.containsMouse ? Appearance.surfaceHighColor : "transparent")

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    Bluetooth.toggleContextMenu(root.device);
                } else {
                    Bluetooth.closeContextMenu();
                    Bluetooth.primaryAction(root.device);
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 8
            spacing: 14

            MaterialSymbol {
                icon: root.deviceIcon(root.device.icon)
                font.pixelSize: 20
                color: root.contentColor

                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.device.name || root.device.address
                    elide: Text.ElideRight
                    font.weight: Font.Medium
                    color: root.contentColor
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Bluetooth.stateText(root.device)
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: root.contentColor
                    opacity: 0.65
                }
            }

            StyledText {
                visible: root.device.batteryAvailable
                text: Math.round(root.device.battery * 100) + "%"
                font.pixelSize: 12
                color: root.contentColor
                opacity: 0.65
            }

            MaterialSymbol {
                visible: !root.device.connected && icon !== ""
                icon: Bluetooth.signalIcon(root.device)
                font.pixelSize: 16
                color: root.contentColor
                opacity: 0.6
            }

            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: 18
                color: moreArea.containsMouse || root.menuOpen ? Qt.alpha(root.contentColor, 0.14) : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    icon: "more_horiz"
                    font.pixelSize: 21
                    color: root.contentColor
                }

                MouseArea {
                    id: moreArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bluetooth.toggleContextMenu(root.device)
                }
            }
        }

        Behavior on color {
            ColorAnimation { duration: Appearance.animFast }
        }
    }

    Rectangle {
        id: menuPanel

        readonly property int menuHeight: menuContent.implicitHeight + 12
        readonly property real rowY: root.menuHost ? root.mapToItem(root.menuHost, 0, 0).y : root.y

        parent: root.menuOpen && root.menuHost ? root.menuHost : root
        x: root.menuOpen && root.menuHost ? root.mapToItem(root.menuHost, 0, 0).x + root.width - width - 8 : root.width - width - 8
        y: root.menuOpen && root.menuHost
            ? (rowY + root.height + menuHeight <= root.menuHost.height
                ? rowY + root.height - 2
                : Math.max(0, rowY - menuHeight + 10))
            : root.height - 2
        width: Math.min(260, root.width - 16)
        height: menuHeight
        visible: root.menuOpen
        z: 10000
        radius: 20
        color: Appearance.bgColor
        border.width: 1
        border.color: Appearance.hairlineColor

        ColumnLayout {
            id: menuContent

            anchors.fill: parent
            anchors.margins: 6
            spacing: 3

            ListRow {
                Layout.fillWidth: true
                implicitHeight: 44
                first: true
                last: !root.device.paired
                visible: root.device.paired || root.device.connected
                icon: root.device.connected ? "link_off" : "link"
                title: root.device.connected ? "Disconnect" : "Connect"
                onClicked: {
                    Bluetooth.closeContextMenu();
                    if (root.device.connected) root.device.disconnect();
                    else Bluetooth.connectDevice(root.device);
                }
            }

            ListRow {
                Layout.fillWidth: true
                implicitHeight: 44
                first: !root.device.paired && !(root.device.paired || root.device.connected)
                last: !root.device.paired
                visible: !root.device.paired
                icon: root.device.pairing ? "close" : "add_link"
                title: root.device.pairing ? "Cancel pairing" : "Pair device"
                onClicked: {
                    Bluetooth.closeContextMenu();
                    if (root.device.pairing) root.device.cancelPair();
                    else Bluetooth.pairDevice(root.device);
                }
            }

            ListRow {
                Layout.fillWidth: true
                implicitHeight: 44
                first: !root.device.paired && !root.device.connected
                last: !root.device.blocked && !(root.device.paired || root.device.connected)
                visible: root.device.paired || root.device.connected || root.device.trusted
                icon: root.device.trusted ? "verified_user" : "shield"
                title: root.device.trusted ? "Trusted" : "Trust"
                active: root.device.trusted
                onClicked: {
                    root.device.trusted = !root.device.trusted;
                    Bluetooth.closeContextMenu();
                }
            }

            ListRow {
                Layout.fillWidth: true
                implicitHeight: 44
                first: !root.device.paired && !root.device.connected && !root.device.trusted
                last: !(root.device.paired || root.device.trusted || root.device.blocked)
                icon: root.device.blocked ? "check_circle" : "block"
                title: root.device.blocked ? "Unblock" : "Block"
                visible: root.device.paired || root.device.connected || root.device.blocked
                onClicked: {
                    root.device.blocked = !root.device.blocked;
                    Bluetooth.closeContextMenu();
                }
            }

            ListRow {
                Layout.fillWidth: true
                implicitHeight: 44
                last: true
                visible: root.device.paired || root.device.trusted || root.device.blocked
                icon: "delete"
                title: "Forget device"
                onClicked: Bluetooth.forget(root.device)
            }
        }
    }
}
