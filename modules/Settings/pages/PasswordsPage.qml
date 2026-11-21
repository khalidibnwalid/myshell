import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell

SettingsPage {
    id: page

    property string query: ""
    // the keyring whose "Add a password" form is open, and the item or keyring waiting for a second click
    property string adding: ""
    property string confirming: ""
    property bool creating: false
    property bool creatingKey: false
    // "passwords", "ssh" or "gpg"
    property string tab: "passwords"
    readonly property bool onPasswords: tab === "passwords"
    readonly property var keyrings: Keyring.shown()
    readonly property int total: keyrings.reduce((n, k) => n + k.items.length, 0)

    function matches(item) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return true;
        const attrs = Object.keys(item.attrs).map(k => item.attrs[k]).join(" ");
        return (item.label + " " + attrs).toLowerCase().indexOf(q) !== -1;
    }

    // a friendly line from the attributes apps store: who, where, which app
    function describe(item) {
        const a = item.attrs;
        const parts = [];
        const who = a.user || a.username || a.account || a.login || a.email || "";
        const where = a.server || a.host || a.domain || a.origin_url || a.signon_realm || a.service || "";
        if (who)
            parts.push(who);
        if (where && where !== item.label)
            parts.push(where);
        const app = Keyring.appFor(item)?.name || a.application || "";
        if (app && app !== item.label)
            parts.push(app);
        const schema = a["xdg:schema"] || "";
        if (schema.indexOf("NetworkManager") !== -1)
            parts.push("Network");
        if (item.modified > 0)
            parts.push("Changed " + Qt.formatDate(new Date(item.modified * 1000), "d MMM yyyy"));
        return parts.join("  ·  ");
    }

    function iconFor(item) {
        const schema = item.attrs["xdg:schema"] || "";
        if (schema.indexOf("NetworkManager") !== -1)
            return "wifi_password";
        if (item.attrs.origin_url || item.attrs.signon_realm)
            return "language";
        if (schema.indexOf("chrome") !== -1 || item.attrs.application)
            return "apps";
        return "key";
    }

    function confirm(key) {
        if (confirming === key) {
            confirming = "";
            return true;
        }
        confirming = key;
        confirmTimer.restart();
        return false;
    }

    function count(n, one, many) {
        return n + " " + (n === 1 ? one : many);
    }

    title: "Passwords & keys"
    subtitle: tab === "ssh" ? count(UserKeys.ssh.length, "SSH key", "SSH keys") + " in ~/.ssh" : tab === "gpg" ? count(UserKeys.gpg.length, "GPG key", "GPG keys") : (!Keyring.available ? "" : count(total, "saved password", "saved passwords") + " in " + count(keyrings.length, "keyring", "keyrings"))
    Component.onCompleted: {
        Keyring.refresh();
        UserKeys.refresh();
    }

    headerActions: [
        PillButton {
            visible: page.onPasswords && Keyring.available
            icon: "add"
            text: "New keyring"
            toggled: page.creating
            onClicked: page.creating = !page.creating
        },
        PillButton {
            visible: page.tab === "ssh"
            icon: "add"
            text: "New SSH key"
            toggled: page.creatingKey
            onClicked: page.creatingKey = !page.creatingKey
        }
    ]

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            Keyring.refresh();
            UserKeys.refresh();
        }
    }

    Timer {
        id: confirmTimer

        interval: 4000
        onTriggered: page.confirming = ""
    }

    SettingGroup {
        SettingRow {
            icon: page.onPasswords ? "password" : page.tab === "ssh" ? "terminal" : "verified_user"
            title: page.onPasswords ? "Saved passwords" : page.tab === "ssh" ? "SSH keys" : "GPG keys"
            description: page.onPasswords ? "What apps keep in your keyrings" : page.tab === "ssh" ? "Sign you in to servers and Git hosts" : "Sign and encrypt mail, files and commits"

            Segmented {
                model: [
                    {
                        "label": "Passwords",
                        "value": "passwords"
                    },
                    {
                        "label": "SSH",
                        "value": "ssh"
                    }
                ].concat(UserKeys.gpgAvailable ? [
                    {
                        "label": "GPG",
                        "value": "gpg"
                    }
                ] : [])
                value: page.tab
                onSelected: v => {
                    page.tab = v;
                    page.confirming = "";
                }
            }
        }
    }

    SettingGroup {
        visible: page.onPasswords && Keyring.loaded && !Keyring.available

        SettingRow {
            icon: "error"
            title: "No keyring service is running"
            description: "Apps keep passwords in a keyring such as gnome-keyring. Install it and start it with your session."
        }
    }

    SettingGroup {
        visible: page.onPasswords && page.creating

        title: "New keyring"

        SettingRow {
            icon: "add_moderator"
            title: "Name"
            description: "The keyring asks you for its password next"

            FieldInput {
                id: newName

                implicitWidth: 220
                placeholder: "Work"
                onAccepted: create.clicked()
            }

            PillButton {
                id: create

                text: "Create"
                enabled: newName.text.trim() !== ""
                onClicked: {
                    if (!enabled)
                        return;
                    Keyring.create(newName.text.trim());
                    newName.clear();
                    page.creating = false;
                }
            }
        }
    }

    SettingGroup {
        visible: page.onPasswords && Keyring.available && page.total > 0

        SettingRow {
            icon: "search"
            title: "Find a password"
            description: Keyring.message !== "" ? Keyring.message : "By name, account, website or app"

            FieldInput {
                implicitWidth: 240
                placeholder: "Search"
                icon: "search"
                onEdited: text => page.query = text
            }
        }
    }

    SettingGroup {
        visible: page.onPasswords && Keyring.available && page.total === 0 && Keyring.message !== ""

        SettingRow {
            icon: "info"
            title: Keyring.message
        }
    }

    Repeater {
        model: page.keyrings

        delegate: SettingGroup {
            id: group

            required property var modelData
            readonly property bool session: modelData.path.endsWith("/collection/session")
            readonly property var items: modelData.items.filter(i => page.matches(i))

            visible: page.onPasswords && (page.query === "" || items.length > 0)
            title: Keyring.name(modelData)

            SettingRow {
                icon: group.modelData.locked ? "lock" : "lock_open"
                title: group.modelData.locked ? "Locked" : "Unlocked"
                description: [group.modelData.items.length + (group.modelData.items.length === 1 ? " password" : " passwords"), group.modelData.default ? "Default: apps save new passwords here" : "", group.session ? "Kept in memory only" : ""].filter(Boolean).join("  ·  ")

                PillButton {
                    visible: !group.session
                    icon: group.modelData.locked ? "lock_open" : "lock"
                    text: group.modelData.locked ? "Unlock" : "Lock"
                    onClicked: group.modelData.locked ? Keyring.unlock(group.modelData.path) : Keyring.lock(group.modelData.path)
                }

                PillButton {
                    visible: !group.session && !group.modelData.default
                    text: "Make default"
                    onClicked: Keyring.setDefault(group.modelData.path)
                }

                PillButton {
                    visible: !group.session
                    icon: "password"
                    text: "Change password"
                    onClicked: Keyring.changePassword(group.modelData.path)
                }

                PillButton {
                    icon: "add"
                    text: "Add"
                    toggled: page.adding === group.modelData.path
                    enabled: !group.modelData.locked
                    onClicked: page.adding = page.adding === group.modelData.path ? "" : group.modelData.path
                }

                PillButton {
                    visible: !group.session && !group.modelData.default
                    icon: "delete"
                    text: page.confirming === group.modelData.path ? "Delete all?" : "Delete"
                    toggled: page.confirming === group.modelData.path
                    onClicked: {
                        if (page.confirm(group.modelData.path))
                            Keyring.remove(group.modelData.path, Keyring.name(group.modelData));
                    }
                }
            }

            SettingCard {
                visible: page.adding === group.modelData.path

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        FieldInput {
                            id: addName

                            Layout.fillWidth: true
                            placeholder: "Name or website"
                            icon: "label"
                        }

                        FieldInput {
                            id: addAccount

                            Layout.fillWidth: true
                            placeholder: "Account (optional)"
                            icon: "person"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        FieldInput {
                            id: addSecret

                            Layout.fillWidth: true
                            placeholder: "Password"
                            icon: "password"
                            password: true
                            onAccepted: save.clicked()
                        }

                        PillButton {
                            text: "Cancel"
                            onClicked: page.adding = ""
                        }

                        PillButton {
                            id: save

                            icon: "save"
                            text: "Save"
                            toggled: enabled
                            enabled: addName.text.trim() !== "" && addSecret.text !== ""
                            onClicked: {
                                if (!enabled)
                                    return;
                                Keyring.store(group.modelData.path, addName.text.trim(), addAccount.text.trim(), addSecret.text);
                                addName.clear();
                                addAccount.clear();
                                addSecret.clear();
                                page.adding = "";
                            }
                        }
                    }
                }
            }

            Repeater {
                model: group.items

                delegate: SettingRow {
                    id: row

                    required property var modelData
                    readonly property string appIcon: Keyring.iconFor(modelData)

                    image: appIcon
                    icon: appIcon !== "" ? "" : page.iconFor(modelData)
                    title: modelData.label || "No name"
                    description: page.describe(modelData)

                    PillButton {
                        icon: "content_copy"
                        text: "Copy"
                        onClicked: Keyring.copy(row.modelData.path, row.title)
                    }

                    PillButton {
                        icon: "delete"
                        text: page.confirming === row.modelData.path ? "Confirm" : "Delete"
                        toggled: page.confirming === row.modelData.path
                        onClicked: {
                            if (page.confirm(row.modelData.path))
                                Keyring.remove(row.modelData.path, row.title);
                        }
                    }
                }
            }

            SettingRow {
                visible: group.modelData.items.length === 0
                icon: "key_off"
                title: "Nothing saved here"
                description: "Apps save passwords in the default keyring"
            }
        }
    }

    // SSH

    SettingGroup {
        visible: page.tab === "ssh" && page.creatingKey
        title: "New SSH key"

        SettingCard {
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FieldInput {
                    id: keyName

                    Layout.fillWidth: true
                    placeholder: "File name: " + (UserKeys.ssh.some(k => k.name === "id_ed25519") ? "id_ed25519_work" : "id_ed25519")
                    icon: "key"
                }

                FieldInput {
                    id: keyComment

                    Layout.fillWidth: true
                    placeholder: "Comment (optional, e.g. your email)"
                    icon: "label"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FieldInput {
                    id: keyPass

                    Layout.fillWidth: true
                    placeholder: "Passphrase (optional)"
                    icon: "password"
                    password: true
                    onAccepted: makeKey.clicked()
                }

                PillButton {
                    text: "Cancel"
                    onClicked: page.creatingKey = false
                }

                PillButton {
                    id: makeKey

                    readonly property string fileName: keyName.text.trim() !== "" ? keyName.text.trim() : (UserKeys.ssh.some(k => k.name === "id_ed25519") ? "" : "id_ed25519")

                    icon: "add"
                    text: "Create"
                    toggled: enabled
                    enabled: /^[A-Za-z0-9._-]+$/.test(fileName) && !UserKeys.ssh.some(k => k.name === fileName)
                    onClicked: {
                        if (!enabled)
                            return;
                        UserKeys.createSsh(fileName, keyComment.text.trim(), keyPass.text);
                        keyName.clear();
                        keyComment.clear();
                        keyPass.clear();
                        page.creatingKey = false;
                    }
                }
            }
        }
    }

    SettingGroup {
        visible: page.tab !== "passwords" && UserKeys.message !== ""

        SettingRow {
            icon: "info"
            title: UserKeys.message
        }
    }

    SettingGroup {
        visible: page.tab === "ssh"
        title: "In ~/.ssh"

        SettingRow {
            visible: UserKeys.ssh.length === 0
            icon: "key_off"
            title: "No SSH keys yet"
            description: UserKeys.sshAvailable ? "Make one with New SSH key, then add its public half to your server or Git host" : "Install openssh to make and use SSH keys"
        }

        Repeater {
            model: UserKeys.ssh

            delegate: SettingRow {
                id: sshRow

                required property var modelData

                icon: "key"
                title: modelData.name
                description: [modelData.type + (modelData.type === "ED25519" ? "" : " " + modelData.bits), modelData.comment, modelData.hasPrivate ? "" : "Public half only", modelData.fingerprint.length > 24 ? modelData.fingerprint.slice(0, 14) + "…" + modelData.fingerprint.slice(-6) : modelData.fingerprint].filter(Boolean).join("  ·  ")

                PillButton {
                    icon: "content_copy"
                    text: "Copy public key"
                    onClicked: UserKeys.copySsh(sshRow.modelData)
                }

                PillButton {
                    icon: "delete"
                    text: page.confirming === sshRow.modelData.file ? "Move to trash?" : "Delete"
                    toggled: page.confirming === sshRow.modelData.file
                    onClicked: {
                        if (page.confirm(sshRow.modelData.file))
                            UserKeys.trashSsh(sshRow.modelData);
                    }
                }
            }
        }
    }

    // GPG

    SettingGroup {
        visible: page.tab === "gpg"
        title: "Your keys and the ones you imported"

        SettingRow {
            visible: UserKeys.gpg.length === 0
            icon: "key_off"
            title: "No GPG keys yet"
            description: "Make one with: gpg --full-generate-key"
        }

        Repeater {
            model: UserKeys.gpg

            delegate: SettingRow {
                id: gpgRow

                required property var modelData
                readonly property string who: modelData.uids[0] || modelData.id

                icon: modelData.secret ? "verified_user" : "shield_person"
                title: who
                description: [modelData.secret ? "Yours (has the secret key)" : "Public key", modelData.revoked ? "Revoked" : modelData.expired ? "Expired" : modelData.expires > 0 ? "Expires " + Qt.formatDate(new Date(modelData.expires * 1000), "d MMM yyyy") : "", modelData.uids.length > 1 ? "+" + (modelData.uids.length - 1) + " more" : "", modelData.id].filter(Boolean).join("  ·  ")

                PillButton {
                    icon: "content_copy"
                    text: "Copy public key"
                    onClicked: UserKeys.copyGpg(gpgRow.modelData)
                }

                PillButton {
                    visible: !gpgRow.modelData.secret
                    icon: "delete"
                    text: page.confirming === gpgRow.modelData.fingerprint ? "Confirm" : "Delete"
                    toggled: page.confirming === gpgRow.modelData.fingerprint
                    onClicked: {
                        if (page.confirm(gpgRow.modelData.fingerprint))
                            UserKeys.deleteGpg(gpgRow.modelData);
                    }
                }
            }
        }
    }
}
