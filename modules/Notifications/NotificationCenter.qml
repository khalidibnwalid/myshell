import "../../config"
import "../../services"
import QtQuick
import Quickshell

// Floating notification toasts. They hide after a timeout but stay in the
// notification panel (next to the quick settings) until dismissed.
Scope {
    PanelWindow {
        anchors.top: true
        anchors.right: Config.panelRight
        anchors.left: !Config.panelRight
        margins.top: 10
        margins.right: 10
        margins.left: 10
        implicitWidth: 364
        implicitHeight: Math.min(640, Math.max(1, list.contentHeight))
        color: "transparent"
        visible: NotificationService.popups.count > 0 || hideDelay.running

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

                Timer {
                    interval: toast.model.timeout > 0 ? toast.model.timeout : Math.max(1, Config.notifications.popupSeconds) * 1000
                    running: true
                    onTriggered: NotificationService.hidePopup(toast.model.nid)
                }
            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.animNormal
                }

                NumberAnimation {
                    property: "x"
                    from: 40
                    to: 0
                    duration: Appearance.animSlow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeOut
                }
            }

            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Appearance.animNormal
                }

                NumberAnimation {
                    property: "x"
                    to: 40
                    duration: Appearance.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.easeStandard
                }
            }

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
