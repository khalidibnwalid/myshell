import "../../components"
import "../../config"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var notification
    property string summary
    property string body
    property string appName
    property string appIcon
    readonly property int timeout: notification ? notification.expireTimeout : -1

    signal dismissed()

    implicitWidth: 350
    implicitHeight: layout.implicitHeight + 24
    radius: 16
    color: Appearance.bgColor
    opacity: 0.95
    border.color: Appearance.borderColor
    border.width: 1
    Component.onCompleted: {
        root.opacity = 0;
        root.scale = 0.8;
        entryAnim.start();
    }
    ListView.onRemove: {
        removeAnim.start();
    }

    Timer {
        interval: timeout > 0 ? timeout : 5000
        running: timeout !== 0
        onTriggered: {
            if (root.notification)
                root.notification.expire();

            root.dismissed();
        }
    }

    RowLayout {
        id: layout

        spacing: 12

        anchors {
            fill: parent
            margins: 12
        }

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: 8
            color: Appearance.accentColor
            opacity: 0.2

            Image {
                anchors.fill: parent
                anchors.margins: 4
                source: root.appIcon.startsWith("/") ? "file://" + root.appIcon : (root.appIcon !== "" ? "image://icon/" + root.appIcon : "")
                fillMode: Image.PreserveAspectFit
                visible: source != ""
            }

            MaterialSymbol {
                anchors.centerIn: parent
                icon: "notifications"
                font.pixelSize: 24
                color: Appearance.accentColor
                visible: !root.appIcon
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.summary
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Appearance.fgColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.appName
                    font.pixelSize: 10
                    color: Appearance.fgColor
                    opacity: 0.5
                }

            }

            Text {
                text: root.body
                font.pixelSize: 13
                color: Appearance.fgColor
                opacity: 0.8
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

        }

        IconButton {
            icon: "close"
            iconSize: 18
            onClicked: {
                if (root.notification)
                    root.notification.dismiss();

                root.dismissed();
            }
        }

    }

    ParallelAnimation {
        id: entryAnim

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0.95
            duration: 300
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: 400
            easing.type: Easing.OutBack
        }

    }

    SequentialAnimation {
        id: removeAnim

        PropertyAction {
            target: root
            property: "ListView.delayRemove"
            value: true
        }

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: 250
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            to: 0.8
            duration: 250
            easing.type: Easing.OutCubic
        }

        PropertyAction {
            target: root
            property: "ListView.delayRemove"
            value: false
        }

    }

}
