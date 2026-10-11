// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

Item {
    id: sw

    property alias text: textLabel.text
    property alias description: descLabel.text
    property bool checked: false

    signal clicked()

    width: parent ? parent.width : 0
    height: Math.max(Theme.itemSizeSmall, textColumn.height + 2 * Theme.paddingMedium)

    Rectangle {
        id: indicator
        x: Theme.horizontalPageMargin
        y: Theme.paddingLarge
        width: 28; height: 28; radius: 14
        color: sw.checked ? Theme.highlightColor : "transparent"
        border.color: Theme.highlightColor
        border.width: 2
    }
    Column {
        id: textColumn
        anchors { left: indicator.right; leftMargin: Theme.paddingLarge; right: parent.right; rightMargin: Theme.horizontalPageMargin }
        y: Theme.paddingMedium
        Label { id: textLabel; width: parent.width; wrapMode: Text.Wrap }
        Label {
            id: descLabel
            width: parent.width
            visible: text.length > 0
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { sw.checked = !sw.checked; sw.clicked() }
    }
}
