// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    property var tasks: []
    property bool showArchived: false
    property bool loaded: false

    function load() {
        backend.run("tasks", [true], function(t) { if (page) { page.tasks = t; page.loaded = true } })
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
                text: page.showArchived ? /*% "Hide archived" */ qsTrId("timerecord-tasks-hide-archived") : /*% "Show archived" */ qsTrId("timerecord-tasks-show-archived")
                onClicked: page.showArchived = !page.showArchived
            }
            MenuItem {
                //% "Add task"
                text: qsTrId("timerecord-tasks-add-task")
                onClicked: pageStack.push(Qt.resolvedUrl("TaskDialog.qml"))
            }
        }

        //% "Tasks"
        header: PageHeader { title: qsTrId("timerecord-tasks-tasks") }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            opacity: modelData.archived ? Theme.opacityHigh : 1
            onClicked: pageStack.push(Qt.resolvedUrl("TaskDialog.qml"), { task: modelData })
            menu: ContextMenu {
                MenuItem {
                    text: modelData.archived ? /*% "Restore" */ qsTrId("timerecord-tasks-restore") : /*% "Archive" */ qsTrId("timerecord-tasks-archive")
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
                //% "(archived)"
                text: modelData.name + (modelData.archived ? " " + qsTrId("timerecord-tasks-archived") : "")
                color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                truncationMode: TruncationMode.Fade
            }
        }

        ViewPlaceholder {
            enabled: page.loaded && list.count === 0
            text: page.tasks.length > 0 ? /*% "All tasks are archived" */ qsTrId("timerecord-tasks-all-tasks-are-archived") : /*% "No tasks" */ qsTrId("timerecord-tasks-no-tasks")
            hintText: page.tasks.length > 0 ? /*% "Pull down to show them" */ qsTrId("timerecord-tasks-pull-down-to-show-them") : /*% "Pull down to add one" */ qsTrId("timerecord-tasks-pull-down-to-add-one")
        }

        VerticalScrollDecorator { }
    }
}
