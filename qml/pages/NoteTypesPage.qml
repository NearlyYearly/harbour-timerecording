// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    property var types: []
    property bool showArchived: false
    property bool loaded: false

    function load() {
        backend.run("note_types", [true], function(t) { if (page) { page.types = t; page.loaded = true } })
    }

    Component.onCompleted: load()
    Connections {
        target: backend
        onDataChanged: page.load()
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.types.filter(function(t) { return page.showArchived || !t.archived })

        PullDownMenu {
            MenuItem {
                text: page.showArchived ? /*% "Hide archived" */ qsTrId("timerecord-note-types-hide-archived") : /*% "Show archived" */ qsTrId("timerecord-note-types-show-archived")
                onClicked: page.showArchived = !page.showArchived
            }
            MenuItem {
                //% "Add day type"
                text: qsTrId("timerecord-note-types-add-day-type")
                onClicked: pageStack.push(Qt.resolvedUrl("NoteTypeDialog.qml"))
            }
        }

        //% "Day types"
        header: PageHeader { title: qsTrId("timerecord-note-types-day-types") }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeMedium
            opacity: modelData.archived ? Theme.opacityHigh : 1
            onClicked: pageStack.push(Qt.resolvedUrl("NoteTypeDialog.qml"), { type: modelData })
            menu: ContextMenu {
                MenuItem {
                    text: modelData.archived ? /*% "Restore" */ qsTrId("timerecord-note-types-restore") : /*% "Archive" */ qsTrId("timerecord-note-types-archive")
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
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    //% "target credit %1% · vacation days %2"
                    text: qsTrId("timerecord-note-types-target-credit-vacation-days").arg(Math.round(modelData.credit_factor * 100)).arg(modelData.holiday_days)
                }
            }
        }
        ViewPlaceholder {
            enabled: page.loaded && list.count === 0
            text: page.types.length > 0 ? /*% "All day types are archived" */ qsTrId("timerecord-note-types-all-day-types-are-archived") : /*% "No day types" */ qsTrId("timerecord-note-types-no-day-types")
            hintText: page.types.length > 0 ? /*% "Pull down to show them" */ qsTrId("timerecord-note-types-pull-down-to-show-them") : /*% "Pull down to add one" */ qsTrId("timerecord-note-types-pull-down-to-add-one")
        }
        VerticalScrollDecorator { }
    }
}
