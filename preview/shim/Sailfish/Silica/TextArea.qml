// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

FocusScope {
    id: area

    property alias text: edit.text
    property string label
    property string placeholderText

    width: parent ? parent.width : 0
    height: column.height + Theme.paddingMedium

    Column {
        id: column
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        y: Theme.paddingMedium
        spacing: Theme.paddingSmall

        TextEdit {
            id: edit
            width: parent.width
            height: Math.max(contentHeight, Theme.itemSizeSmall)
            focus: true
            wrapMode: TextEdit.Wrap
            color: Theme.primaryColor
            selectionColor: Theme.highlightBackgroundColor
            font.pixelSize: Theme.fontSizeMedium
            Label {
                visible: !edit.text && !edit.activeFocus
                text: area.placeholderText
                color: Theme.secondaryColor
            }
        }
        Rectangle {
            width: parent.width
            height: 2
            color: edit.activeFocus ? Theme.highlightColor : Theme.secondaryHighlightColor
        }
        Label {
            text: area.label
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryHighlightColor
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: edit.forceActiveFocus()
        enabled: !edit.activeFocus
    }
}
