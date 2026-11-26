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
                title: dialog.line ? /*% "Edit line" */ qsTrId("timerecord-edit-stamp-dialog-edit-line") : /*% "Add line" */ qsTrId("timerecord-edit-stamp-dialog-add-line")
            }

            //% "Time"
            SectionHeader { text: qsTrId("timerecord-edit-stamp-dialog-time") }

            ValueButton {
                //% "Date"
                label: qsTrId("timerecord-edit-stamp-dialog-date")
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
                    //% "In"
                    label: qsTrId("timerecord-edit-stamp-dialog-in")
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
                    //% "Out"
                    label: qsTrId("timerecord-edit-stamp-dialog-out")
                    value: dialog.openEnded ? "–"
                                            : Format.pad(dialog.effectiveOut.getHours()) + ":" + Format.pad(dialog.effectiveOut.getMinutes())
                    description: dialog.openEnded ? ""
                                 //% "Duration %1"
                                 : qsTrId("timerecord-edit-stamp-dialog-duration").arg(Format.duration((dialog.effectiveOut - dialog.checkIn) / 60000))
                                   //% "next day"
                                   + (dialog.effectiveOut.getDate() !== dialog.checkIn.getDate() ? " · " + qsTrId("timerecord-edit-stamp-dialog-next-day") : "")
                    onClicked: dialog.pickTime(dialog.checkOut, function(h, m) {
                        var d = new Date(dialog.checkIn)
                        d.setHours(h, m, 0, 0)
                        dialog.checkOut = d
                    })
                }
            }

            TextSwitch {
                //% "Still running"
                text: qsTrId("timerecord-edit-stamp-dialog-still-running")
                //% "No check-out yet"
                description: qsTrId("timerecord-edit-stamp-dialog-no-check-out-yet")
                checked: dialog.openEnded
                onCheckedChanged: dialog.openEnded = checked
            }

            //% "Details"
            SectionHeader { text: qsTrId("timerecord-edit-stamp-dialog-details") }

            TextSwitch {
                //% "Break"
                text: qsTrId("timerecord-edit-stamp-dialog-break")
                //% "Counts as break time, no task"
                description: qsTrId("timerecord-edit-stamp-dialog-counts-as-break-time-no-task")
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
                //% "Comment"
                label: qsTrId("timerecord-edit-stamp-dialog-comment")
                placeholderText: label
                text: dialog.line ? dialog.line.comment : ""
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
        }

        VerticalScrollDecorator { }
    }
}
