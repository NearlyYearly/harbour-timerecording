// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

Dialog {
    id: dialog

    property var task: null
    property string taskColor: task ? task.color : String(Theme.highlightColor)
    property bool targetOff: task ? !!task.target_off : false
    property real holiday: task ? task.holiday_days : 0
    readonly property var holidayValues: [0, 1, 0.5]

    canAccept: nameField.text.trim().length > 0 && factorField.acceptableInput
    onAccepted: {
        var data = { name: nameField.text, color: taskColor, work_factor: Number(factorField.text) / 100,
                     target_off: targetOff, holiday_days: holiday }
        if (task) backend.mutate("update_task", [task.id, data])
        else backend.mutate("add_task", [nameField.text, taskColor, data])
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader { title: dialog.task ? /*% "Edit task" */ qsTrId("timerecord-task-dialog-edit-task") : /*% "Add task" */ qsTrId("timerecord-task-dialog-add-task") }

            TextField {
                id: nameField
                width: parent.width
                //% "Name"
                label: qsTrId("timerecord-task-dialog-name")
                placeholderText: label
                text: dialog.task ? dialog.task.name : ""
                focus: !dialog.task
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: factorField.focus = true
            }

            ColorButton {
                value: dialog.taskColor
                onValueChanged: dialog.taskColor = value
            }

            //% "Rules"
            SectionHeader { text: qsTrId("timerecord-task-dialog-rules") }

            NumberField {
                id: factorField
                width: parent.width
                //% "Counts as work (%)"
                label: qsTrId("timerecord-task-dialog-counts-as-work")
                //% "0 for time that is recorded but not worked, like on call"
                description: qsTrId("timerecord-task-dialog-0-for-time-that-is-recorded")
                value: dialog.task ? Math.round(dialog.task.work_factor * 100) : 100
                maximum: 100
            }

            TextSwitch {
                //% "No target on these days"
                text: qsTrId("timerecord-task-dialog-no-target-on-these-days")
                //% "A day with only lines of this task has no target, like a public holiday"
                description: qsTrId("timerecord-task-dialog-a-day-with-only-lines-of")
                checked: dialog.targetOff
                onClicked: dialog.targetOff = checked
            }

            ComboBox {
                //% "Uses vacation"
                label: qsTrId("timerecord-task-dialog-uses-vacation")
                //% "For each day with a line of this task"
                description: qsTrId("timerecord-task-dialog-for-each-day-with-a-line")
                currentIndex: Math.max(0, dialog.holidayValues.indexOf(dialog.holiday))
                menu: ContextMenu {
                    //% "No"
                    MenuItem { text: qsTrId("timerecord-task-dialog-no"); onClicked: dialog.holiday = 0 }
                    //% "1 day"
                    MenuItem { text: qsTrId("timerecord-task-dialog-1-day"); onClicked: dialog.holiday = 1 }
                    //% "½ day"
                    MenuItem { text: qsTrId("timerecord-task-dialog-day"); onClicked: dialog.holiday = 0.5 }
                }
            }
        }

        VerticalScrollDecorator { }
    }
}
