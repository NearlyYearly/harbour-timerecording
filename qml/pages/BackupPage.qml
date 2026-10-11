// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

SettingsBase {
    id: page

    property var backups: []
    property string message: ""

    function loadBackups() {
        backend.run("list_backups", [], function(b) { page.backups = b })
    }

    Component.onCompleted: loadBackups()

    RemorsePopup { id: remorse }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.backups

        PullDownMenu {
            MenuItem {
                text: qsTr("Export backup now")
                onClicked: backend.run("export_backup", [], function(path) {
                    page.message = qsTr("Saved %1").arg(path)
                    page.loadBackups()
                })
            }
        }

        header: Column {
            width: list.width

            PageHeader { title: qsTr("Backup & general") }

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
                label: qsTr("Automatic backup every (days, 0 = off)")
                value: page.values ? page.values["backup.auto_days"] : 0
                maximum: 365
                onCommitted: page.save("backup.auto_days", value)
            }

            NumberField {
                width: parent.width
                label: qsTr("Automatic backups to keep")
                value: page.values ? page.values["backup.keep"] : 1
                minimum: 1
                maximum: 1000
                onCommitted: page.save("backup.keep", value)
            }

            NumberField {
                width: parent.width
                label: qsTr("Ignore repeated check-in/out within (seconds)")
                value: page.values ? page.values["punch.debounce_sec"] : 0
                maximum: 600
                onCommitted: page.save("punch.debounce_sec", value)
            }

            NumberField {
                width: parent.width
                label: qsTr("Undo steps")
                value: page.values ? page.values["undo.depth"] : 1
                minimum: 1
                maximum: 1000
                onCommitted: page.save("undo.depth", value)
            }

            SectionHeader { text: qsTr("Backups in Documents") }
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Restore")
                    onClicked: {
                        var path = modelData.path
                        remorse.execute(qsTr("Replacing all data"), function() {
                            backend.mutate("restore_backup", [path], function(count) {
                                page.message = qsTr("Restored %1 records. The previous data was saved first.").arg(count)
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
                    color: Theme.secondaryColor
                }
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            text: qsTr("No backups yet")
            hintText: qsTr("Pull down to export one")
        }

        VerticalScrollDecorator { }
    }
}
