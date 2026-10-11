import QtQuick 2.6
import Sailfish.Silica 1.0

// Lists Time Recording (Android) backups in Documents; tapping one opens the preview.
Page {
    id: page

    property var files: []
    property bool loaded: false

    function load() {
        backend.run("android_backups", [], function(f) { page.files = f; page.loaded = true })
    }

    Component.onCompleted: load()

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.files

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.load()
            }
        }

        header: Column {
            width: list.width

            PageHeader { title: qsTr("Import from Android") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: qsTr("In Time Recording on Android, make a backup and copy the file (timerec.db.gz) to Documents on this phone.")
            }

            SectionHeader { text: qsTr("Backups in Documents") }
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
                    color: Theme.secondaryColor
                }
            }
        }

        ViewPlaceholder {
            enabled: page.loaded && list.count === 0
            text: qsTr("No backup found")
            hintText: qsTr("Copy timerec.db.gz to Documents, then pull down to refresh")
        }

        VerticalScrollDecorator { }
    }
}
