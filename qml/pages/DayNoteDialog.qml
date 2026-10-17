// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components/Format.js" as Format

// Day note: a type (vacation, sick, ...) that can credit the target, plus free text.
Dialog {
    id: dialog

    property string date
    // Several days (DaysPage): the same note on each, one undo step.
    property var dates: []
    property var note: null
    property var types: []
    property var typeId: note ? note.note_type_id : null

    Component.onCompleted: backend.run("note_types", [], function(t) { if (dialog) dialog.types = t })

    onAccepted: {
        if (dates.length > 0) {
            var n = dates.length
            backend.mutate("set_day_notes", [dates, backend.optId(typeId), textArea.text], function() {
                backend.notice(qsTr("Day note set on %n day(s)", "", n))
            })
        } else {
            backend.mutate("set_day_note", [date, backend.optId(typeId), textArea.text])
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            visible: !!dialog.note
            MenuItem {
                text: qsTr("Clear note")
                onClicked: {
                    dialog.typeId = null
                    textArea.text = ""
                    dialog.accept()
                }
            }
        }

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: dialog.dates.length > 0 ? qsTr("%n day(s)", "", dialog.dates.length)
                                               : Format.parseDate(dialog.date).toLocaleDateString(Qt.locale(), "ddd d MMM yyyy")
            }

            ComboBox {
                id: typeBox
                label: qsTr("Day type")
                readonly property var entries: [{ id: null, name: qsTr("None"), credit_factor: 0, holiday_days: 0 }].concat(dialog.types)
                currentIndex: {
                    // -1 until the menu items exist; Silica rejects an index it has no item for.
                    if (typeItems.count < entries.length) return -1
                    for (var i = 0; i < entries.length; i++)
                        if (entries[i].id === dialog.typeId) return i
                    return 0
                }
                description: {
                    var e = entries[currentIndex]
                    if (!e || e.id === null) return ""
                    var parts = []
                    if (e.credit_factor > 0) parts.push(qsTr("credits %1% of the target").arg(Math.round(e.credit_factor * 100)))
                    if (e.holiday_days > 0) parts.push(qsTr("uses %1 vacation days").arg(e.holiday_days))
                    return parts.join(" · ")
                }
                menu: ContextMenu {
                    Repeater {
                        id: typeItems
                        model: typeBox.entries
                        MenuItem {
                            text: modelData.name
                            onClicked: dialog.typeId = modelData.id
                        }
                    }
                }
            }

            TextArea {
                id: textArea
                width: parent.width
                label: qsTr("Note")
                placeholderText: label
                text: dialog.note ? dialog.note.text : ""
            }
        }
    }
}
