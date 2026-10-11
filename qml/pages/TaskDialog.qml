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

            DialogHeader { title: dialog.task ? qsTr("Edit task") : qsTr("Add task") }

            TextField {
                id: nameField
                width: parent.width
                label: qsTr("Name")
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

            SectionHeader { text: qsTr("Rules") }

            NumberField {
                id: factorField
                width: parent.width
                label: qsTr("Counts as work (%)")
                description: qsTr("0 for time that is recorded but not worked, like on call")
                value: dialog.task ? Math.round(dialog.task.work_factor * 100) : 100
                maximum: 100
            }

            TextSwitch {
                text: qsTr("No target on these days")
                description: qsTr("A day with only lines of this task has no target, like a public holiday")
                checked: dialog.targetOff
                onClicked: dialog.targetOff = checked
            }

            ComboBox {
                label: qsTr("Uses holiday")
                description: qsTr("For each day with a line of this task")
                currentIndex: Math.max(0, dialog.holidayValues.indexOf(dialog.holiday))
                menu: ContextMenu {
                    MenuItem { text: qsTr("No"); onClicked: dialog.holiday = 0 }
                    MenuItem { text: qsTr("1 day"); onClicked: dialog.holiday = 1 }
                    MenuItem { text: qsTr("½ day"); onClicked: dialog.holiday = 0.5 }
                }
            }
        }

        VerticalScrollDecorator { }
    }
}
