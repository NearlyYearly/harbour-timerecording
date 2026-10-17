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
        backend.run("templates", [], function(t) { page.templates = t })
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
                text: qsTr("Save this day as template")
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("TextDialog.qml"),
                                                { title: qsTr("New template"), label: qsTr("Name") })
                    dialog.accepted.connect(function() {
                        backend.mutate("save_template", [dialog.text, page.date], function(t) { if (t) page.templates = t })
                    })
                }
            }
        }

        header: PageHeader {
            title: qsTr("Templates")
            description: page.dates.length > 0
                         ? qsTr("Tap to add to %n day(s)", "", page.dates.length)
                         : qsTr("Tap to add to %1").arg(Format.parseDate(page.date).toLocaleDateString(Qt.locale(), "ddd d MMM"))
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
                    text: qsTr("Rename")
                    onClicked: {
                        var id = modelData.id
                        var dialog = pageStack.push(Qt.resolvedUrl("TextDialog.qml"),
                                                    { title: qsTr("Rename template"), label: qsTr("Name"), text: modelData.name })
                        dialog.accepted.connect(function() {
                            backend.mutate("rename_template", [id, dialog.text], function(t) { if (t) page.templates = t })
                        })
                    }
                }
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: {
                        var id = modelData.id
                        item.remorseAction(qsTr("Deleting"), function() {
                            backend.mutate("delete_template", [id], function(t) { if (t) page.templates = t })
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
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                    text: modelData.lines.map(function(l) {
                        return (l.kind === "break" ? qsTr("break") + " " : "") + l.start + "–" + l.end
                    }).join(", ")
                }
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            text: qsTr("No templates")
            hintText: page.canSave ? qsTr("Pull down to save this day as a template")
                                   : qsTr("Open a day with finished lines and save it as a template")
        }
        VerticalScrollDecorator { }
    }
}
