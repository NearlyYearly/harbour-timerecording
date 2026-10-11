// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    property var tasks: []
    property bool showArchived: false

    function load() {
        backend.run("tasks", [true], function(t) { page.tasks = t })
    }

    Component.onCompleted: load()
    Connections {
        target: backend
        onDataChanged: page.load()
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.tasks.filter(function(t) { return page.showArchived || !t.archived })

        PullDownMenu {
            MenuItem {
                text: page.showArchived ? qsTr("Hide archived") : qsTr("Show archived")
                onClicked: page.showArchived = !page.showArchived
            }
            MenuItem {
                text: qsTr("Add task")
                onClicked: pageStack.push(Qt.resolvedUrl("TaskDialog.qml"))
            }
        }

        header: PageHeader { title: qsTr("Tasks") }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            opacity: modelData.archived ? Theme.opacityHigh : 1
            onClicked: pageStack.push(Qt.resolvedUrl("TaskDialog.qml"), { task: modelData })
            menu: ContextMenu {
                MenuItem {
                    text: modelData.archived ? qsTr("Restore") : qsTr("Archive")
                    onClicked: backend.mutate("archive_task", [modelData.id, !modelData.archived])
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
            Label {
                anchors {
                    left: dot.right; leftMargin: Theme.paddingLarge
                    right: parent.right; rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: modelData.name + (modelData.archived ? " " + qsTr("(archived)") : "")
                color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                truncationMode: TruncationMode.Fade
            }
        }

        VerticalScrollDecorator { }
    }
}
