// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components/Format.js" as Format

// Quick day type: one tap sets the type of `date` and keeps the note text.
Page {
    id: page

    property string date
    property var note: null
    property var types: []
    readonly property var currentId: note ? note.note_type_id : null

    Component.onCompleted: backend.run("note_types", [], function(t) { if (page) page.types = t })

    SilicaListView {
        id: list
        anchors.fill: parent
        model: [{ id: null, name: qsTr("None"), color: "", credit_factor: 0, holiday_days: 0 }].concat(page.types)

        header: PageHeader {
            title: qsTr("Day type")
            description: Format.parseDate(page.date).toLocaleDateString(Qt.locale(), "ddd d MMM yyyy")
        }

        delegate: ListItem {
            id: item
            readonly property bool current: modelData.id === page.currentId
            contentHeight: Theme.itemSizeMedium
            onClicked: {
                var text = page.note ? page.note.text : ""
                backend.mutate("set_day_note", [page.date, backend.optId(modelData.id), text], function(st) {
                    if (st) pageStack.pop()
                })
            }
            Rectangle {
                visible: modelData.color.length > 0
                width: Theme.paddingSmall
                height: parent.height - Theme.paddingSmall
                anchors.verticalCenter: parent.verticalCenter
                x: Theme.horizontalPageMargin - Theme.paddingMedium
                color: modelData.color || Theme.highlightColor
            }
            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    text: modelData.name
                    color: item.current || item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.bold: item.current
                    truncationMode: TruncationMode.Fade
                }
                Label {
                    width: parent.width
                    visible: text.length > 0
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                    text: {
                        var parts = []
                        if (modelData.credit_factor > 0) parts.push(qsTr("credits %1% of the target").arg(Math.round(modelData.credit_factor * 100)))
                        if (modelData.holiday_days > 0) parts.push(qsTr("uses %1 vacation days").arg(modelData.holiday_days))
                        return parts.join(" · ")
                    }
                }
            }
        }

        VerticalScrollDecorator { }
    }
}
