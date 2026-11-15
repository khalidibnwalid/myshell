import "../../../components"
import "../../../config"
import "../../../services"
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page

    title: "Printers & scanners"
    subtitle: Printers.printers.length === 0 ? "Nothing set up yet" : Printers.printers.length + (Printers.printers.length === 1 ? " printer" : " printers") + (Printers.jobs.length > 0 ? " · " + Printers.jobs.length + " in the queue" : "")
    Component.onCompleted: {
        Printers.refresh();
        Printers.refreshScanners();
    }

    headerActions: [
        PillButton {
            icon: "add"
            text: "Add or manage"
            onClicked: Printers.openAdmin("")
        }
    ]

    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: Printers.refresh()
    }

    SettingGroup {
        visible: !Printers.serviceRunning

        SettingRow {
            icon: "error"
            title: "The printing service is not running"
            description: "Start it with: systemctl enable --now cups"
        }
    }

    Repeater {
        model: Printers.printers

        delegate: SettingGroup {
            id: group

            required property var modelData
            readonly property bool isDefault: Printers.defaultPrinter === modelData.name

            title: modelData.name.replace(/_/g, " ")

            SettingRow {
                icon: group.modelData.state === "printing" ? "print" : (group.modelData.enabled ? "print" : "print_disabled")
                title: group.modelData.model || group.modelData.name
                description: (group.modelData.state === "printing" ? "Printing now" : (group.modelData.enabled ? "Ready" : "Off or unplugged")) + (group.modelData.reasons && group.modelData.reasons !== "none" && !group.modelData.enabled ? "  ·  " + group.modelData.reasons : "") + (group.isDefault ? "  ·  Default" : "")

                PillButton {
                    visible: !group.isDefault
                    text: "Make default"
                    onClicked: Printers.setDefault(group.modelData.name)
                }

                PillButton {
                    icon: "description"
                    text: "Test page"
                    enabled: group.modelData.enabled
                    onClicked: Printers.testPage(group.modelData.name)
                }

                PillButton {
                    icon: "settings"
                    text: "Options"
                    onClicked: Printers.openAdmin(group.modelData.name)
                }
            }

            // ink or toner, when the printer reports it
            Repeater {
                model: group.modelData.markers

                delegate: MeterRow {
                    required property var modelData

                    icon: "water_drop"
                    title: modelData.name
                    detail: modelData.level + "%"
                    value: modelData.level / 100
                    barColor: modelData.level <= 10 ? "#f2b8b5" : Appearance.accentColor
                }
            }

            SettingRow {
                readonly property var mine: Printers.jobs.filter(j => j.printer === group.modelData.name)

                visible: mine.length > 0
                icon: "queue"
                title: mine.length + (mine.length === 1 ? " job waiting" : " jobs waiting")
                description: "From " + mine.map(j => j.user).filter((u, i, a) => a.indexOf(u) === i).join(", ")

                PillButton {
                    icon: "cancel"
                    text: "Cancel all"
                    onClicked: Printers.cancelJobs(group.modelData.name)
                }
            }
        }
    }

    SettingGroup {
        visible: Printers.scanAvailable
        title: "Scanners"

        SettingRow {
            visible: Printers.scanners.length === 0
            icon: "scanner"
            title: "No scanners found"
            description: "Plug one in or turn it on, then search again"

            PillButton {
                icon: "refresh"
                text: "Search again"
                onClicked: Printers.refreshScanners()
            }
        }

        Repeater {
            model: Printers.scanners

            delegate: SettingRow {
                required property var modelData

                icon: "scanner"
                title: modelData.name
                description: modelData.device
            }
        }
    }
}
