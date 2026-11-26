// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

SettingsBase {
    id: page

    property var backups: []
    property string message: ""

    function loadBackups() {
        backend.run("list_backups", [], function(b) { if (page) page.backups = b })
    }

    Component.onCompleted: loadBackups()

    RemorsePopup { id: remorse }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.backups

        PullDownMenu {
            MenuItem {
                //% "Export backup now"
                text: qsTrId("timerecord-backup-export-backup-now")
                onClicked: backend.run("export_backup", [], function(path) {
                    if (!page) return
                    //% "Saved %1"
                    page.message = qsTrId("timerecord-backup-saved").arg(path)
                    page.loadBackups()
                })
            }
        }

        header: Column {
            width: list.width

            //% "Backup & general"
            PageHeader { title: qsTrId("timerecord-backup-backup-general") }

            Label {
                visible: page.message.length > 0
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.WrapAnywhere
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.message
            }

            NumberField {
                width: parent.width
                //% "Automatic backup every (days, 0 = off)"
                label: qsTrId("timerecord-backup-automatic-backup-every-days-0-off")
                value: page.values ? page.values["backup.auto_days"] : 0
                maximum: 365
                onCommitted: page.save("backup.auto_days", value)
            }

            NumberField {
                width: parent.width
                //% "Automatic backups to keep"
                label: qsTrId("timerecord-backup-automatic-backups-to-keep")
                value: page.values ? page.values["backup.keep"] : 1
                minimum: 1
                maximum: 1000
                onCommitted: page.save("backup.keep", value)
            }

            NumberField {
                width: parent.width
                //% "Ignore repeated check-in/out within (seconds)"
                label: qsTrId("timerecord-backup-ignore-repeated-check-in-out-within")
                value: page.values ? page.values["punch.debounce_sec"] : 0
                maximum: 600
                onCommitted: page.save("punch.debounce_sec", value)
            }

            NumberField {
                width: parent.width
                //% "Undo steps"
                label: qsTrId("timerecord-backup-undo-steps")
                value: page.values ? page.values["undo.depth"] : 1
                minimum: 1
                maximum: 1000
                onCommitted: page.save("undo.depth", value)
            }

            //% "Backups in Documents"
            SectionHeader { text: qsTrId("timerecord-backup-backups-in-documents") }
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            menu: ContextMenu {
                MenuItem {
                    //% "Restore"
                    text: qsTrId("timerecord-backup-restore")
                    onClicked: {
                        var path = modelData.path
                        //% "Replacing all data"
                        remorse.execute(qsTrId("timerecord-backup-replacing-all-data"), function() {
                            backend.mutate("restore_backup", [path], function(count) {
                                if (!page) return
                                //% "Restored %1 records. The previous data was saved first."
                                page.message = qsTrId("timerecord-backup-restored-records-the-previous-data-was").arg(count)
                                page.loadBackups()
                            })
                        })
                    }
                }
            }
            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    text: modelData.name
                    font.pixelSize: Theme.fontSizeSmall
                    truncationMode: TruncationMode.Fade
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    text: modelData.mtime.replace("T", " ")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            //% "No backups yet"
            text: qsTrId("timerecord-backup-no-backups-yet")
            //% "Pull down to export one"
            hintText: qsTrId("timerecord-backup-pull-down-to-export-one")
        }

        VerticalScrollDecorator { }
    }
}
