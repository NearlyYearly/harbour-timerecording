// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

Dialog {
    id: dialog

    property int hour: 0
    property int minute: 0
    property int hourMode: 0

    function _pad(n) { return (n < 10 ? "0" : "") + n }

    Column {
        width: parent.width
        spacing: Theme.paddingLarge
        DialogHeader { }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingLarge
            Repeater {
                model: [{ max: 24, step: [1, 6] }, { max: 60, step: [1, 15] }]
                Column {
                    readonly property bool isHour: index === 0
                    readonly property int val: isHour ? dialog.hour : dialog.minute
                    function set(v) {
                        v = (v % modelData.max + modelData.max) % modelData.max
                        if (isHour) dialog.hour = v
                        else dialog.minute = v
                    }
                    spacing: Theme.paddingSmall
                    Repeater {
                        model: [modelData.step[1], modelData.step[0]]
                        Label {
                            width: 160; horizontalAlignment: Text.AlignHCenter
                            text: "+" + modelData
                            color: Theme.highlightColor
                            MouseArea { anchors.fill: parent; onClicked: parent.parent.set(parent.parent.val + modelData) }
                        }
                    }
                    Label {
                        width: 160; horizontalAlignment: Text.AlignHCenter
                        text: dialog._pad(parent.val)
                        font.pixelSize: Theme.fontSizeHuge * 1.5
                        color: Theme.highlightColor
                        MouseArea {
                            anchors.fill: parent
                            onWheel: parent.parent.set(parent.parent.val + (wheel.angleDelta.y > 0 ? 1 : -1))
                        }
                    }
                    Repeater {
                        model: [modelData.step[0], modelData.step[1]]
                        Label {
                            width: 160; horizontalAlignment: Text.AlignHCenter
                            text: "−" + modelData
                            color: Theme.highlightColor
                            MouseArea { anchors.fill: parent; onClicked: parent.parent.set(parent.parent.val - modelData) }
                        }
                    }
                }
            }
        }
    }
}
