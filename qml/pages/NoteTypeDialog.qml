// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

Dialog {
    id: dialog

    property var type: null
    property string typeColor: type ? type.color : String(Theme.highlightColor)
    property real credit: type ? type.credit_factor : 1
    property real holiday: type ? type.holiday_days : 0
    readonly property var factors: [1, 0.5, 0]

    canAccept: nameField.text.trim().length > 0
    onAccepted: {
        var data = { name: nameField.text, color: typeColor, credit_factor: credit, holiday_days: holiday }
        if (type) backend.mutate("update_note_type", [type.id, data])
        else backend.mutate("add_note_type", [data])
    }

    Column {
        width: parent.width
        spacing: Theme.paddingMedium

        DialogHeader { title: dialog.type ? /*% "Edit day type" */ qsTrId("timerecord-note-type-dialog-edit-day-type") : /*% "Add day type" */ qsTrId("timerecord-note-type-dialog-add-day-type") }

        TextField {
            id: nameField
            width: parent.width
            //% "Name"
            label: qsTrId("timerecord-note-type-dialog-name")
            placeholderText: label
            text: dialog.type ? dialog.type.name : ""
            EnterKey.iconSource: "image://theme/icon-m-enter-close"
            EnterKey.onClicked: focus = false
        }

        ComboBox {
            //% "Counts towards target"
            label: qsTrId("timerecord-note-type-dialog-counts-towards-target")
            currentIndex: Math.max(0, dialog.factors.indexOf(dialog.credit))
            //% "A vacation day usually counts as a full day of work, comp time not at all"
            description: qsTrId("timerecord-note-type-dialog-a-vacation-day-usually-counts-as")
            menu: ContextMenu {
                //% "Full day"
                MenuItem { text: qsTrId("timerecord-note-type-dialog-full-day"); onClicked: dialog.credit = 1 }
                //% "Half day"
                MenuItem { text: qsTrId("timerecord-note-type-dialog-half-day"); onClicked: dialog.credit = 0.5 }
                //% "No"
                MenuItem { text: qsTrId("timerecord-note-type-dialog-no"); onClicked: dialog.credit = 0 }
            }
        }

        ComboBox {
            //% "Uses vacation"
            label: qsTrId("timerecord-note-type-dialog-uses-vacation")
            currentIndex: Math.max(0, dialog.factors.indexOf(dialog.holiday))
            menu: ContextMenu {
                //% "1 day"
                MenuItem { text: qsTrId("timerecord-note-type-dialog-1-day"); onClicked: dialog.holiday = 1 }
                //% "½ day"
                MenuItem { text: qsTrId("timerecord-note-type-dialog-day"); onClicked: dialog.holiday = 0.5 }
                //% "No"
                MenuItem { text: qsTrId("timerecord-note-type-dialog-no"); onClicked: dialog.holiday = 0 }
            }
        }

        ColorButton {
            value: dialog.typeColor
            onValueChanged: dialog.typeColor = value
        }
    }
}
