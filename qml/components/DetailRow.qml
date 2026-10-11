// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// "label ........ value" row for read-only figures.
Item {
    property alias label: labelText.text
    property alias value: valueText.text
    property alias valueColor: valueText.color

    width: parent.width
    height: Theme.itemSizeExtraSmall

    Label {
        id: labelText
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.secondaryHighlightColor
    }
    Label {
        id: valueText
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
        color: Theme.highlightColor
    }
}
