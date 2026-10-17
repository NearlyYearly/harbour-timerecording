// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

// Add (line == null) or edit a time line.
Dialog {
    id: dialog

    property var line: null
    property string date
    property var tasks: []

    property date checkIn: line ? Format.parseDateTime(line.check_in) : defaultIn()
    property date checkOut: line && line.check_out ? Format.parseDateTime(line.check_out) : new Date(checkIn.getTime() + 3600000)
    property bool openEnded: !!(line && !line.check_out)
    property var taskId: line ? line.task_id : backend.status.last_task_id
    property string kind: line ? line.kind : "work"

    // Check-out on the next day when it is earlier than check-in.
    readonly property date effectiveOut: {
        var out = new Date(checkIn)
        out.setHours(checkOut.getHours(), checkOut.getMinutes(), 0, 0)
        if (out < checkIn) out.setDate(out.getDate() + 1)
        return out
    }

    function defaultIn() {
        var d = Format.parseDate(date)
        var now = new Date()
        d.setHours(now.getHours(), now.getMinutes(), 0, 0)
        return d
    }

    function pickTime(current, apply) {
        var picker = pageStack.push("Sailfish.Silica.TimePickerDialog",
                                    { hour: current.getHours(), minute: current.getMinutes(),
                                      hourMode: DateTime.TwentyFourHours })
        picker.accepted.connect(function() { apply(picker.hour, picker.minute) })
    }

    canAccept: openEnded || effectiveOut >= checkIn

    onAccepted: {
        var data = {
            check_in: Format.isoDateTime(checkIn),
            check_out: openEnded ? "" : Format.isoDateTime(effectiveOut),
            task_id: kind === "work" ? backend.optId(taskBox.taskId) : -1,
            comment: commentField.text,
            kind: kind
        }
        if (line) backend.mutate("update_stamp", [line.id, data])
        else backend.mutate("add_stamp", [data])
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: dialog.line ? qsTr("Edit line") : qsTr("Add line")
            }

            SectionHeader { text: qsTr("Time") }

            ValueButton {
                label: qsTr("Date")
                value: dialog.checkIn.toLocaleDateString(Qt.locale(), "ddd d MMM yyyy")
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.DatePickerDialog", { date: dialog.checkIn })
                    picker.accepted.connect(function() {
                        var d = new Date(picker.date)
                        d.setHours(dialog.checkIn.getHours(), dialog.checkIn.getMinutes(), 0, 0)
                        dialog.checkIn = d
                    })
                }
            }

            // Check-in and check-out side by side; the check-out is empty while the line runs.
            Row {
                width: parent.width
                ValueButton {
                    width: parent.width / 2
                    label: qsTr("In")
                    value: Format.pad(dialog.checkIn.getHours()) + ":" + Format.pad(dialog.checkIn.getMinutes())
                    onClicked: dialog.pickTime(dialog.checkIn, function(h, m) {
                        var d = new Date(dialog.checkIn)
                        d.setHours(h, m, 0, 0)
                        dialog.checkIn = d
                    })
                }
                ValueButton {
                    width: parent.width / 2
                    enabled: !dialog.openEnded
                    opacity: enabled ? 1 : Theme.opacityLow
                    label: qsTr("Out")
                    value: dialog.openEnded ? "–"
                                            : Format.pad(dialog.effectiveOut.getHours()) + ":" + Format.pad(dialog.effectiveOut.getMinutes())
                    description: dialog.openEnded ? ""
                                 : qsTr("Duration %1").arg(Format.duration((dialog.effectiveOut - dialog.checkIn) / 60000))
                                   + (dialog.effectiveOut.getDate() !== dialog.checkIn.getDate() ? " · " + qsTr("next day") : "")
                    onClicked: dialog.pickTime(dialog.checkOut, function(h, m) {
                        var d = new Date(dialog.checkIn)
                        d.setHours(h, m, 0, 0)
                        dialog.checkOut = d
                    })
                }
            }

            TextSwitch {
                text: qsTr("Still running")
                description: qsTr("No check-out yet")
                checked: dialog.openEnded
                onCheckedChanged: dialog.openEnded = checked
            }

            SectionHeader { text: qsTr("Details") }

            TextSwitch {
                text: qsTr("Break")
                description: qsTr("Counts as break time, no task")
                checked: dialog.kind === "break"
                onCheckedChanged: dialog.kind = checked ? "break" : "work"
            }

            TaskComboBox {
                id: taskBox
                visible: dialog.kind === "work"
                tasks: dialog.tasks
                allowNone: true
                taskId: dialog.taskId
            }

            TextField {
                id: commentField
                width: parent.width
                label: qsTr("Comment")
                placeholderText: label
                text: dialog.line ? dialog.line.comment : ""
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
        }

        VerticalScrollDecorator { }
    }
}
