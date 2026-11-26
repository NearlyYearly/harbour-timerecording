// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Lists Time Recording (Android) backups in Documents; tapping one opens the preview.
Page {
    id: page

    property var files: []
    property bool loaded: false

    function load() {
        backend.run("android_backups", [], function(f) { if (!page) return; page.files = f; page.loaded = true })
    }

    Component.onCompleted: load()

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.files

        PullDownMenu {
            MenuItem {
                //% "Refresh"
                text: qsTrId("timerecord-import-refresh")
                onClicked: page.load()
            }
        }

        header: Column {
            width: list.width

            //% "Import from Android"
            PageHeader { title: qsTrId("timerecord-import-import-from-android") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                //% "In Time Recording on Android, make a backup and copy the file (timerec.db.gz) to Documents on this phone."
                text: qsTrId("timerecord-import-in-time-recording-on-android-make")
            }

            //% "Backups in Documents"
            SectionHeader { text: qsTrId("timerecord-import-backups-in-documents") }
        }

        delegate: BackgroundItem {
            id: item
            height: Theme.itemSizeSmall
            onClicked: pageStack.push(Qt.resolvedUrl("ImportDialog.qml"), { path: modelData.path, name: modelData.name })
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
            enabled: page.loaded && list.count === 0
            //% "No backup found"
            text: qsTrId("timerecord-import-no-backup-found")
            //% "Copy timerec.db.gz to Documents, then pull down to refresh"
            hintText: qsTrId("timerecord-import-copy-timerec-db-gz-to-documents")
        }

        VerticalScrollDecorator { }
    }
}
