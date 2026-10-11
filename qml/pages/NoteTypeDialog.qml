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

        DialogHeader { title: dialog.type ? qsTr("Edit day type") : qsTr("Add day type") }

        TextField {
            id: nameField
            width: parent.width
            label: qsTr("Name")
            placeholderText: label
            text: dialog.type ? dialog.type.name : ""
        }

        ComboBox {
            label: qsTr("Counts towards target")
            currentIndex: Math.max(0, dialog.factors.indexOf(dialog.credit))
            description: qsTr("A vacation day usually counts as a full day of work, comp time not at all")
            menu: ContextMenu {
                MenuItem { text: qsTr("Full day"); onClicked: dialog.credit = 1 }
                MenuItem { text: qsTr("Half day"); onClicked: dialog.credit = 0.5 }
                MenuItem { text: qsTr("No"); onClicked: dialog.credit = 0 }
            }
        }

        ComboBox {
            label: qsTr("Uses vacation")
            currentIndex: Math.max(0, dialog.factors.indexOf(dialog.holiday))
            menu: ContextMenu {
                MenuItem { text: qsTr("1 day"); onClicked: dialog.holiday = 1 }
                MenuItem { text: qsTr("½ day"); onClicked: dialog.holiday = 0.5 }
                MenuItem { text: qsTr("No"); onClicked: dialog.holiday = 0 }
            }
        }

        ColorButton {
            value: dialog.typeColor
            onValueChanged: dialog.typeColor = value
        }
    }
}
