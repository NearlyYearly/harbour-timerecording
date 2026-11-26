// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components/Format.js" as Format

// Day templates: tap to add a template's lines to `date`, save the day as a new template.
Page {
    id: page

    property string date
    // Several days (DaysPage): a tap adds the template to each of them.
    property var dates: []
    property bool canSave: false
    property var templates: []

    function load() {
        backend.run("templates", [], function(t) { if (page) page.templates = t })
    }

    Component.onCompleted: load()

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.templates

        PullDownMenu {
            visible: page.dates.length === 0
            MenuItem {
                enabled: page.canSave
                //% "Save this day as template"
                text: qsTrId("timerecord-templates-save-this-day-as-template")
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("TextDialog.qml"),
                                                { title: /*% "New template" */ qsTrId("timerecord-templates-new-template"), label: /*% "Name" */ qsTrId("timerecord-templates-name") })
                    dialog.accepted.connect(function() {
                        backend.mutate("save_template", [dialog.text, page.date], function(t) { if (t && page) page.templates = t })
                    })
                }
            }
        }

        header: PageHeader {
            //% "Templates"
            title: qsTrId("timerecord-templates-templates")
            description: page.dates.length > 0
                         //% "Tap to add to %n day(s)"
                         ? qsTrId("timerecord-templates-tap-to-add-to-day-s", page.dates.length)
                         //% "Tap to add to %1"
                         : qsTrId("timerecord-templates-tap-to-add-to").arg(Format.parseDate(page.date).toLocaleDateString(Qt.locale(), "ddd d MMM"))
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeMedium
            onClicked: {
                var several = page.dates.length > 0
                backend.mutate(several ? "apply_template_days" : "apply_template",
                               [modelData.id, several ? page.dates : page.date], function(st) {
                    if (st) pageStack.pop()
                })
            }
            menu: ContextMenu {
                MenuItem {
                    //% "Rename"
                    text: qsTrId("timerecord-templates-rename")
                    onClicked: {
                        var id = modelData.id
                        var dialog = pageStack.push(Qt.resolvedUrl("TextDialog.qml"),
                                                    { title: /*% "Rename template" */ qsTrId("timerecord-templates-rename-template"), label: /*% "Name" */ qsTrId("timerecord-templates-name"), text: modelData.name })
                        dialog.accepted.connect(function() {
                            backend.mutate("rename_template", [id, dialog.text], function(t) { if (t && page) page.templates = t })
                        })
                    }
                }
                MenuItem {
                    //% "Delete"
                    text: qsTrId("timerecord-templates-delete")
                    onClicked: {
                        var id = modelData.id
                        //% "Deleting"
                        item.remorseAction(qsTrId("timerecord-templates-deleting"), function() {
                            backend.mutate("delete_template", [id], function(t) { if (t && page) page.templates = t })
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
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }
                Label {
                    width: parent.width
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                    text: modelData.lines.map(function(l) {
                        //% "break"
                        return (l.kind === "break" ? qsTrId("timerecord-templates-break") + " " : "") + l.start + "–" + l.end
                    }).join(", ")
                }
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            //% "No templates"
            text: qsTrId("timerecord-templates-no-templates")
            //% "Pull down to save this day as a template"
            hintText: page.canSave ? qsTrId("timerecord-templates-pull-down-to-save-this-day")
                                   //% "Open a day with finished lines and save it as a template"
                                   : qsTrId("timerecord-templates-open-a-day-with-finished-lines")
        }
        VerticalScrollDecorator { }
    }
}
