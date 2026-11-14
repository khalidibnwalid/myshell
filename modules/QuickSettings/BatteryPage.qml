import "../../components/"
import "../../config/"
import "../../services/"
import QtQuick
import QtQuick.Layouts

Item {
    property var stackView

    implicitHeight: layout.implicitHeight + 32

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 14

        PageHeader {
            Layout.fillWidth: true
            title: "Battery"
            subtitle: Battery.stateString
            onBack: stackView.pop()
        }

        // charge level
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 24
            color: Appearance.surfaceColor
            clip: true

            Rectangle {
                height: parent.height
                width: Math.max(height, parent.width * Battery.percentage)
                radius: height / 2
                color: Appearance.accentColor

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.animSlow
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.easeOut
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    visible: parent.width > 80
                    text: Math.round(Battery.percentage * 100) + "%"
                    color: Appearance.accentContrastColor
                    font.weight: Font.DemiBold
                }

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    icon: Battery.iconName
                    fill: Battery.percentage
                    font.pixelSize: 20
                    color: Appearance.accentContrastColor
                }
            }
        }

        StyledText {
            Layout.leftMargin: 6
            Layout.topMargin: 2
            text: "Power profile"
            color: Appearance.mutedColor
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: -6
            spacing: 3

            Repeater {
                id: profiles

                model: Battery.powerProfilesList

                delegate: ListRow {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    first: index === 0
                    last: index === profiles.count - 1
                    title: modelData.name
                    icon: modelData.icon
                    active: Battery.activeProfile === modelData.key
                    trailingIcon: active ? "check" : ""
                    onClicked: Battery.setProfile(modelData.key)
                }
            }
        }
    }
}
