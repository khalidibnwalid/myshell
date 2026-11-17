import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts

SettingsPage {
    id: page

    title: "Accounts"
    subtitle: Accounts.realName !== "" && Accounts.realName !== Accounts.userName ? Accounts.realName + " (" + Accounts.userName + ")" : Accounts.userName
    Component.onCompleted: Accounts.refresh()

    FileDialog {
        id: faceDialog

        title: "Choose your picture"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: Accounts.setFace(decodeURIComponent(selectedFile.toString().replace("file://", "")))
    }

    SettingGroup {
        title: "You"

        SettingRow {
            title: Accounts.realName !== "" ? Accounts.realName : Accounts.userName
            description: Accounts.userName + "  ·  " + (Accounts.admin ? "Administrator" : "Standard user")

            icon: Accounts.hasFace ? "" : "account_circle"
            image: Accounts.hasFace ? "file://" + Accounts.faceFile + "#" + Accounts.faceVersion : ""

            PillButton {
                visible: Accounts.hasFace
                icon: "delete"
                text: "Remove picture"
                onClicked: Accounts.removeFace()
            }

            PillButton {
                icon: "add_a_photo"
                text: "Change picture"
                onClicked: faceDialog.open()
            }
        }

        SettingRow {
            icon: "badge"
            title: "Full name"
            description: "Shown on the lock screen and in the app list"

            FieldInput {
                value: Accounts.realName
                placeholder: "Your name"
                onCommitted: text => Accounts.setRealName(text)
            }
        }

        SettingRow {
            icon: "password"
            title: "Password"
            description: "Opens a terminal to change it"

            PillButton {
                icon: "key"
                text: "Change password"
                onClicked: Accounts.changePassword()
            }
        }

        SettingRow {
            icon: "terminal"
            title: "Login shell"
            description: Accounts.shell

            FieldInput {
                value: Accounts.shell
                placeholder: "/usr/bin/fish"
                onCommitted: text => {
                    if (text !== "" && text !== Accounts.shell)
                        Accounts.changeShell(text);
                }
            }
        }

        SettingRow {
            icon: "computer"
            title: "Computer name"
            description: "Asks for administrator rights"

            FieldInput {
                value: Accounts.hostname
                placeholder: "hostname"
                onCommitted: text => Accounts.setHostname(text)
            }
        }

        SettingRow {
            icon: "group"
            title: "Groups"
            description: Accounts.groups.join(", ")
        }
    }

    SettingGroup {
        visible: Accounts.others.length > 0
        title: "Other people on this computer"

        Repeater {
            model: Accounts.others

            delegate: SettingRow {
                required property var modelData

                icon: "person"
                title: modelData.realName !== "" ? modelData.realName : modelData.name
                description: modelData.name
            }
        }
    }

    SettingGroup {
        title: "Online accounts"

        SettingRow {
            visible: Accounts.online.length === 0
            icon: "cloud_off"
            title: "No online accounts"
            description: Accounts.onlineTool === "" ? "Install gnome-control-center to add Google, Microsoft or Nextcloud accounts" : "Add one for mail, calendar, contacts and files"
        }

        Repeater {
            model: Accounts.online

            delegate: SettingRow {
                required property var modelData

                icon: Accounts.providerIcons[modelData.provider] || "account_circle"
                title: modelData.identity !== "" ? modelData.identity : modelData.id
                description: (Accounts.providerNames[modelData.provider] || modelData.provider) + (modelData.services.length > 0 ? "  ·  " + modelData.services.join(", ") : "")
            }
        }

        SettingRow {
            visible: Accounts.onlineTool !== ""
            icon: "manage_accounts"
            title: "Add or remove accounts"
            description: "Opens GNOME's online accounts window"

            PillButton {
                icon: "open_in_new"
                text: "Open"
                onClicked: Accounts.openOnline()
            }
        }
    }
}
