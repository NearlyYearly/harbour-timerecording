// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

Item {
    id: action
    property string iconSource
    signal triggered()

    width: 117
    height: 80
    Rectangle {
        anchors.fill: parent
        color: Theme.highlightBackgroundColor
        opacity: mouse.pressed ? 0.5 : 0
    }
    Text {
        anchors.centerIn: parent
        text: action.iconSource.indexOf("pause") >= 0 ? "❚❚" : action.iconSource.indexOf("play") >= 0 ? "▶"
              : action.iconSource.indexOf("next") >= 0 ? "»" : "•"
        color: "white"
        font.pixelSize: 36
    }
    MouseArea { id: mouse; anchors.fill: parent; onClicked: action.triggered() }
}
