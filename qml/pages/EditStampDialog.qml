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
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: dialog.line ? qsTr("Edit line") : qsTr("Add line")
            }

            ComboBox {
                label: qsTr("Type")
                currentIndex: dialog.kind === "break" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Work"); onClicked: dialog.kind = "work" }
                    MenuItem { text: qsTr("Break"); onClicked: dialog.kind = "break" }
                }
            }

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

            ValueButton {
                label: qsTr("Check in")
                value: Format.pad(dialog.checkIn.getHours()) + ":" + Format.pad(dialog.checkIn.getMinutes())
                onClicked: dialog.pickTime(dialog.checkIn, function(h, m) {
                    var d = new Date(dialog.checkIn)
                    d.setHours(h, m, 0, 0)
                    dialog.checkIn = d
                })
            }

            TextSwitch {
                text: qsTr("Still running")
                description: qsTr("No check-out yet")
                checked: dialog.openEnded
                onCheckedChanged: dialog.openEnded = checked
            }

            ValueButton {
                visible: !dialog.openEnded
                label: qsTr("Check out")
                value: Format.pad(dialog.effectiveOut.getHours()) + ":" + Format.pad(dialog.effectiveOut.getMinutes())
                       + (dialog.effectiveOut.getDate() !== dialog.checkIn.getDate() ? " " + qsTr("(next day)") : "")
                description: qsTr("Duration %1").arg(Format.duration((dialog.effectiveOut - dialog.checkIn) / 60000))
                onClicked: dialog.pickTime(dialog.checkOut, function(h, m) {
                    var d = new Date(dialog.checkIn)
                    d.setHours(h, m, 0, 0)
                    dialog.checkOut = d
                })
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
