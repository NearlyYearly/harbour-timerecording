import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property string title
    property string label
    property alias text: field.text

    canAccept: field.text.trim().length > 0

    Column {
        width: parent.width
        DialogHeader { title: dialog.title }
        TextField {
            id: field
            width: parent.width
            label: dialog.label
            placeholderText: dialog.label
            focus: true
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
        }
    }
}
