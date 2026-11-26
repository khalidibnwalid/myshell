import "../../components"
import "../../config"
import "../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

// One notification. Used as a floating toast and as a row of the notification panel.
Rectangle {
    id: root

    property var notification // live notification object, may be null
    property string summary
    property string body
    property string appName
    property string appIcon
    property string image
    property string meta // text after the title: age or app name
    property bool inPanel: false
    property bool first: true
    property bool last: true
    property bool expanded: false
    property int cornerRadius: 24
    readonly property string avatarSource: NotificationService.iconSource(image || appIcon)
    // a picture file sent as the icon or image (a screenshot): shown as a preview under the text
    readonly property bool isPicture: /\.(png|jpe?g|webp|gif|bmp)$/i.test(image || appIcon || "")

    // a symbol for the common action names, so the buttons read at a glance
    function actionIcon(a) {
        const t = ((a.identifier || "") + " " + (a.text || "")).toLowerCase();
        const map = [[/edit|annotate/, "edit"], [/save/, "download"], [/copy/, "content_copy"], [/repl/, "reply"], [/open|show|view/, "open_in_new"], [/delete|remove|trash/, "delete"], [/snooze|later|remind/, "snooze"], [/accept|yes|ok|confirm/, "check"], [/decline|reject|no\b|cancel/, "close"], [/mark.*read|read/, "done_all"], [/play|resume/, "play_arrow"], [/pause/, "pause"], [/call|answer/, "call"], [/install|update|upgrade/, "system_update_alt"]];
        for (const m of map)
            if (m[0].test(t))
                return m[1];
        return "";
    }
    // the app's buttons ("Edit", "Reply", ...); "default" is what a click on the body does, so it gets none
    readonly property var actions: notification ? notification.actions.filter(a => a.identifier !== "default" && a.text !== "") : []
    // a toast shows its buttons at once; in the panel they come with the expanded notification
    readonly property bool showActions: inPanel ? expanded : actions.length > 0

    signal closeRequested()
    signal bodyClicked()

    implicitHeight: content.implicitHeight + 28
    color: inPanel ? (hover.hovered ? Appearance.surfaceHighColor : Appearance.surfaceColor) : Appearance.panelColor
    border.width: inPanel ? 0 : 1
    border.color: Appearance.hairlineColor
    topLeftRadius: first ? cornerRadius : 6
    topRightRadius: first ? cornerRadius : 6
    bottomLeftRadius: last ? cornerRadius : 6
    bottomRightRadius: last ? cornerRadius : 6
    clip: true

    HoverHandler {
        id: hover
    }

    // Swipe to dismiss, toward the screen edge the panel sits on (right with the panel on the right):
    // past a third of its width it slides out and goes, otherwise it springs back.
    readonly property int swipeSign: Config.panelRight ? 1 : -1
    property bool leaving: false
    property int leaveDelay: 0
    property bool leaveSilently: false

    // slides out toward the edge and then asks to be closed; `delay` staggers a group ("Clear all"),
    // `silently` leaves the closing to the caller
    function swipeAway(delay, silently) {
        leaveDelay = delay ?? 0;
        leaveSilently = silently ?? false;
        leaving = true;
        leave.start();
    }


    // the way back when the drag is let go too early
    Behavior on x {
        enabled: !swipe.active && !root.leaving

        NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeOut
        }
    }

    SequentialAnimation {
        id: leave

        PauseAnimation {
            duration: root.leaveDelay
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "x"
                to: root.swipeSign * (root.width + 24)
                duration: Appearance.animNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.easeStandard
            }

            NumberAnimation {
                target: root
                property: "opacity"
                to: 0
                duration: Appearance.animNormal
            }
        }

        onFinished: {
            if (!root.leaveSilently)
                root.closeRequested();
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        // the swipe lives on the click area: the area takes the press first, so a handler on the
        // card itself never saw the drag
        DragHandler {
            id: swipe

            target: root
            xAxis.minimum: root.swipeSign > 0 ? 0 : -root.width
            xAxis.maximum: root.swipeSign > 0 ? root.width : 0
            yAxis.enabled: false
            enabled: !root.leaving
            onActiveChanged: {
                if (active)
                    return;
                if (root.x * root.swipeSign > root.width * 0.33)
                    root.swipeAway();
                else
                    root.x = 0;
            }
        }

        onClicked: {
            // clicking the body runs the notification's default action, as the spec intends
            const actions = root.notification ? root.notification.actions : [];
            const action = actions.find(a => a.identifier === "default");
            if (action)
                action.invoke();
            root.bodyClicked();
        }
    }

    ColumnLayout {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // avatar: image / app icon, falling back to an initial
            ClippingRectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: Qt.alpha(Appearance.accentColor, 0.16)

                StyledText {
                    anchors.centerIn: parent
                    visible: avatar.status !== Image.Ready && !root.isPicture
                    text: (root.summary || root.appName || "?").trim().charAt(0).toUpperCase()
                    color: Appearance.accentColor
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: root.isPicture
                    icon: "image"
                    fill: 1
                    font.pixelSize: 20
                    color: Appearance.accentColor
                }

                Image {
                    id: avatar

                    anchors.fill: parent
                    anchors.margins: root.image ? 0 : 8
                    // a picture goes in the preview below instead
                    source: root.isPicture ? "" : root.avatarSource
                    sourceSize: Qt.size(96, 96)
                    fillMode: root.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                RowLayout {
                    id: titleRow

                    Layout.fillWidth: true
                    spacing: 5

                    StyledText {
                        Layout.maximumWidth: titleRow.width - metaText.implicitWidth - 5
                        text: root.summary
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        id: metaText

                        visible: root.meta !== ""
                        text: "· " + root.meta
                        color: Appearance.mutedColor
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.body
                    textFormat: Text.PlainText
                    color: Qt.alpha(Appearance.fgColor, 0.82)
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: root.expanded ? 8 : (root.inPanel ? 1 : 2)
                }
            }

            // panel: expand chevron, toast: close
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: btnArea.containsMouse ? Qt.alpha(Appearance.fgColor, 0.2) : Appearance.surfaceHighColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    icon: root.inPanel ? "keyboard_arrow_down" : "close"
                    font.pixelSize: root.inPanel ? 20 : 16
                    color: Appearance.fgColor
                    rotation: root.expanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Appearance.animNormal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.easeStandard
                        }
                    }
                }

                MouseArea {
                    id: btnArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.inPanel ? root.expanded = !root.expanded : root.closeRequested()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animFast
                    }
                }
            }
        }

        // the picture itself (a screenshot), when the notification carries one. Its height is fixed, so the
        // card has its final size from the start: a height that changed once the picture loaded made the
        // toasts overlap.
        ClippingRectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 52
            visible: root.isPicture
            implicitHeight: 110
            radius: 12
            color: Appearance.surfaceColor

            MaterialSymbol {
                anchors.centerIn: parent
                visible: preview.status !== Image.Ready
                icon: "image"
                font.pixelSize: 24
                color: Appearance.mutedColor
            }

            Image {
                id: preview

                anchors.fill: parent
                source: root.isPicture ? root.avatarSource : ""
                anchors.margins: 4
                sourceSize.width: 640
                // the whole shot, not its middle: a tall or wide one would lose what matters
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        // the app's buttons, sharing the width; the first is the main one. A notification that is
        // not resident goes away once one is picked.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 52
            visible: root.showActions && (root.actions.length > 0 || root.inPanel)
            spacing: 6

            Repeater {
                model: root.actions.concat(root.inPanel ? [{
                        "identifier": "__dismiss",
                        "text": "Dismiss"
                    }] : [])

                delegate: Rectangle {
                    id: actionButton

                    required property var modelData
                    required property int index
                    readonly property bool main: index === 0 && modelData.identifier !== "__dismiss"
                    readonly property string symbol: modelData.identifier === "__dismiss" ? "close" : root.actionIcon(modelData)

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 34
                    radius: 12
                    color: main ? Qt.alpha(Appearance.accentColor, actionArea.containsMouse ? 0.3 : 0.18) : (actionArea.containsMouse ? Appearance.surfaceHighColor : Qt.alpha(Appearance.fgColor, 0.07))
                    scale: actionArea.pressed ? 0.96 : 1
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.text
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            actionButton.run();
                            event.accepted = true;
                        }
                    }

                    function run() {
                        if (modelData.identifier === "__dismiss")
                            root.closeRequested();
                        else
                            modelData.invoke();
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animFast
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 16)
                        spacing: 6

                        MaterialSymbol {
                            visible: actionButton.symbol !== ""
                            icon: actionButton.symbol
                            font.pixelSize: 17
                            color: actionButton.main ? Appearance.accentColor : Appearance.fgColor
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: actionButton.modelData.text
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: actionButton.main ? Appearance.accentColor : Appearance.fgColor
                        }
                    }

                    FocusRing {
                    }

                    MouseArea {
                        id: actionArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: actionButton.run()
                    }
                }
            }
        }
    }

    Behavior on implicitHeight {
        enabled: root.inPanel

        NumberAnimation {
            duration: Appearance.animNormal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.easeStandard
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
        }
    }
}
