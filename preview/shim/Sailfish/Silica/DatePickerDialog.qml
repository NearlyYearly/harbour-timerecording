// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

Dialog {
    id: dialog

    property date date: new Date()
    property date _month: new Date(date.getFullYear(), date.getMonth(), 1)

    function _shift(n) { _month = new Date(_month.getFullYear(), _month.getMonth() + n, 1) }

    Column {
        width: parent.width
        DialogHeader { }
        Row {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            height: Theme.itemSizeSmall
            Label {
                width: 60; text: "‹"; font.pixelSize: Theme.fontSizeExtraLarge; color: Theme.highlightColor
                MouseArea { anchors.fill: parent; onClicked: dialog._shift(-1) }
            }
            Label {
                width: parent.width - 120
                horizontalAlignment: Text.AlignHCenter
                text: dialog._month.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeLarge
            }
            Label {
                width: 60; text: "›"; horizontalAlignment: Text.AlignRight
                font.pixelSize: Theme.fontSizeExtraLarge; color: Theme.highlightColor
                MouseArea { anchors.fill: parent; onClicked: dialog._shift(1) }
            }
        }
        Grid {
            id: grid
            columns: 7
            x: Theme.horizontalPageMargin
            readonly property real cell: (dialog.width - 2 * Theme.horizontalPageMargin) / 7
            readonly property int offset: (dialog._month.getDay() + 6) % 7
            Repeater {
                model: 42
                Rectangle {
                    readonly property date day: new Date(dialog._month.getFullYear(), dialog._month.getMonth(), index - grid.offset + 1)
                    readonly property bool selected: day.toDateString() === dialog.date.toDateString()
                    width: grid.cell
                    height: grid.cell
                    radius: width / 2
                    color: selected ? Theme.highlightBackgroundColor : "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: parent.day.getDate()
                        color: parent.day.getMonth() === dialog._month.getMonth() ? Theme.primaryColor : Theme.secondaryColor
                        font.bold: parent.day.toDateString() === new Date().toDateString()
                    }
                    MouseArea { anchors.fill: parent; onClicked: dialog.date = parent.day }
                }
            }
        }
    }
}
