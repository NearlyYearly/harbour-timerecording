// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    property var types: []
    property bool showArchived: false

    function load() {
        backend.run("note_types", [true], function(t) { page.types = t })
    }

    Component.onCompleted: load()
    Connections {
        target: backend
        onDataChanged: page.load()
    }

    SilicaListView {
        anchors.fill: parent
        model: page.types.filter(function(t) { return page.showArchived || !t.archived })

        PullDownMenu {
            MenuItem {
                text: page.showArchived ? qsTr("Hide archived") : qsTr("Show archived")
                onClicked: page.showArchived = !page.showArchived
            }
            MenuItem {
                text: qsTr("Add day type")
                onClicked: pageStack.push(Qt.resolvedUrl("NoteTypeDialog.qml"))
            }
        }

        header: PageHeader { title: qsTr("Day types") }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeMedium
            opacity: modelData.archived ? Theme.opacityHigh : 1
            onClicked: pageStack.push(Qt.resolvedUrl("NoteTypeDialog.qml"), { type: modelData })
            menu: ContextMenu {
                MenuItem {
                    text: modelData.archived ? qsTr("Restore") : qsTr("Archive")
                    onClicked: backend.mutate("update_note_type", [modelData.id, { archived: modelData.archived ? 0 : 1 }])
                }
            }
            Rectangle {
                id: dot
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSizeExtraSmall
                height: width
                radius: width / 2
                color: modelData.color
            }
            Column {
                anchors {
                    left: dot.right; leftMargin: Theme.paddingLarge
                    right: parent.right; rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    text: modelData.name
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }
                Label {
                    width: parent.width
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: qsTr("target credit %1% · vacation days %2").arg(Math.round(modelData.credit_factor * 100)).arg(modelData.holiday_days)
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
