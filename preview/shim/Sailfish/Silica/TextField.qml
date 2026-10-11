// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

FocusScope {
    id: field

    property alias text: input.text
    property alias validator: input.validator
    property alias acceptableInput: input.acceptableInput
    property alias inputMethodHints: input.inputMethodHints
    property alias horizontalAlignment: input.horizontalAlignment
    property alias readOnly: input.readOnly
    property string label
    property string placeholderText
    property string description

    width: parent ? parent.width : 0
    height: column.height + Theme.paddingMedium

    Column {
        id: column
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        y: Theme.paddingMedium
        spacing: Theme.paddingSmall

        TextInput {
            id: input
            width: parent.width
            focus: true
            color: Theme.primaryColor
            selectionColor: Theme.highlightBackgroundColor
            font.pixelSize: Theme.fontSizeMedium
            onAccepted: focus = false
            Label {
                visible: !input.text && !input.activeFocus
                text: field.placeholderText
                color: Theme.secondaryColor
            }
        }
        Rectangle {
            width: parent.width
            height: 2
            color: input.activeFocus ? Theme.highlightColor : Theme.secondaryHighlightColor
        }
        Label {
            visible: input.text.length > 0 || input.activeFocus
            text: field.label
            font.pixelSize: Theme.fontSizeExtraSmall
            color: input.acceptableInput ? Theme.secondaryHighlightColor : "#ef5350"
        }
        Label {
            visible: field.description.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            text: field.description
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryColor
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
        enabled: !input.activeFocus
    }
}
