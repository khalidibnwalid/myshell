import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "../../config"
import "./pages"
import "../../services/"

ApplicationWindow {
    id: root
    width: 800
    height: 600
    title: "Settings"
    visible: WindowManager.settingsVisible
    color: Appearance.bgColor

    onClosing: WindowManager.settingsVisible = false

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: sideMenu
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: Appearance.bgColor

            ColumnLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                ToggleButton {
                    text: "General"
                    icon: "settings"
                    Layout.fillWidth: true
                    toggled: stackView.currentIndex === 0
                    onClicked: stackView.currentIndex = 0
                }

                ToggleButton {
                    text: "Appearance"
                    icon: "palette"
                    Layout.fillWidth: true
                    toggled: stackView.currentIndex === 1
                    onClicked: stackView.currentIndex = 1
                }

                ToggleButton {
                    text: "About"
                    icon: "info"
                    Layout.fillWidth: true
                    toggled: stackView.currentIndex === 2
                    onClicked: stackView.currentIndex = 2
                }
            }
        }

        StackLayout {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            General {}
            AppearancePage {}
            About {}
        }
    }
}
