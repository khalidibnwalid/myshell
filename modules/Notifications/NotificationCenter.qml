import "../../config"
import "../../services"
import QtQuick
import Quickshell

// Floating notification toasts. They hide after a timeout but stay in the
// notification panel (next to the quick settings) until dismissed.
Scope {
    PanelWindow {
        id: toastWindow

        anchors.top: true
        anchors.right: Config.panelRight
        anchors.left: !Config.panelRight
        margins.top: 10
        margins.right: 10
        margins.left: 10
        implicitWidth: 364
        // as tall as the toasts need, up to the screen (at most three are shown, see NotificationService)
        // The window grows at once for a new toast but shrinks only after a leaving one has slid out:
        // the list's height drops the moment a toast is removed, which cut the leaving one off.
        property real heldHeight: 1
        readonly property real wantedHeight: Math.min((screen?.height ?? 1080) - 20, Math.max(1, list.contentHeight))

        onWantedHeightChanged: {
            if (wantedHeight >= heldHeight) {
                heldHeight = wantedHeight;
                shrink.stop();
            } else {
                shrink.restart();
            }
        }

        Timer {
            id: shrink

            interval: Appearance.animNormal + 40
            onTriggered: toastWindow.heldHeight = toastWindow.wantedHeight
        }

        implicitHeight: heldHeight
        color: "transparent"
        // kept up while the last toast slides out (shrink waits for it)
        visible: NotificationService.popups.count > 0 || hideDelay.running || shrink.running

        // keep the window alive while the last toast animates out
        Timer {
            id: hideDelay

            interval: Appearance.animSlow
        }

        Connections {
            function onCountChanged() {
                if (NotificationService.popups.count === 0)
                    hideDelay.restart();
            }

            target: NotificationService.popups
        }

        ListView {
            id: list

            anchors.fill: parent
            model: NotificationService.popups
            spacing: 8
            interactive: false

            delegate: NotificationItem {
                id: toast

                required property var model

                width: list.width
                notification: NotificationService.find(model.nid)
                summary: model.summary || model.appName
                body: model.body
                appName: model.appName
                appIcon: model.appIcon
                image: model.image
                meta: model.summary ? model.appName : ""
                onBodyClicked: NotificationService.hidePopup(model.nid)
                onCloseRequested: NotificationService.dismiss(model.nid)

                // The toast slides in from the screen edge and back out when it goes (timed out, dismissed
                // or swiped). It moves by its own offset, not by x, which the list and the swipe both set;
                // and it starts a moment after it is made, once Hyprland has put the window on screen
                // (sliding while the window still fades in looked like a plain fade).
                transform: Translate {
                    id: slide

                    x: list.edgeX
                }

                SequentialAnimation {
                    running: true

                    PauseAnimation {
                        duration: 60
                    }

                    NumberAnimation {
                        target: slide
                        property: "x"
                        to: 0
                        duration: 420
                        easing.type: Easing.OutCubic
                    }
                }

                // marked as leaving by NotificationService.hidePopup, which removes it once this is done
                readonly property bool leaving: model.leaving === true
                onLeavingChanged: {
                    if (leaving)
                        leaveAnim.start();
                }

                SequentialAnimation {
                    id: leaveAnim

                    NumberAnimation {
                        target: slide
                        property: "x"
                        to: list.edgeX
                        duration: Appearance.animNormal
                        easing.type: Easing.InCubic
                    }

                }

                Timer {
                    interval: toast.model.timeout > 0 ? toast.model.timeout : Math.max(1, Config.notifications.popupSeconds) * 1000
                    running: true
                    onTriggered: NotificationService.hidePopup(toast.model.nid)
                }
            }

            // where a toast comes from and goes to: past the screen edge the panel is on
            readonly property real edgeX: (Config.panelRight ? 1 : -1) * (width + 24)

            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Appearance.animSlow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeOut
                }

                NumberAnimation {
                    property: "opacity"
                    to: 1
                    duration: Appearance.animFast
                }
            }
        }
    }
}
