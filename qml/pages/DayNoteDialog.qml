import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components/Format.js" as Format

// Day note: a type (vacation, sick, ...) that can credit the target, plus free text.
Dialog {
    id: dialog

    property string date
    property var note: null
    property var types: []
    property var typeId: note ? note.note_type_id : null

    Component.onCompleted: backend.run("note_types", [], function(t) { dialog.types = t })

    onAccepted: backend.mutate("set_day_note", [date, backend.optId(typeId), textArea.text])

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
                title: Format.parseDate(dialog.date).toLocaleDateString(Qt.locale(), "ddd d MMM yyyy")
            }

            ComboBox {
                id: typeBox
                label: qsTr("Day type")
                readonly property var entries: [{ id: null, name: qsTr("None"), credit_factor: 0, holiday_days: 0 }].concat(dialog.types)
                currentIndex: {
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
