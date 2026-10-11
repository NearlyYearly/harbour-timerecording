// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// "Color ●" row that opens Silica's color picker; `value` is the chosen color as "#rrggbb".
BackgroundItem {
    id: button

    property string label: qsTr("Color")
    property string value

    width: parent ? parent.width : 0
    height: Theme.itemSizeSmall

    onClicked: {
        var picker = pageStack.push("Sailfish.Silica.ColorPickerDialog", { color: value || Theme.highlightColor })
        picker.accepted.connect(function() { button.value = String(picker.color) })
    }

    Label {
        id: text
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        text: button.label
        color: button.highlighted ? Theme.highlightColor : Theme.primaryColor
    }
    Rectangle {
        anchors { left: text.right; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
        width: Theme.iconSizeSmall
        height: width
        radius: width / 2
        color: button.value || Theme.highlightColor
    }
}
