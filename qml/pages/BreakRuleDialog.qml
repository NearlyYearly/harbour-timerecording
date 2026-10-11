// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components/Format.js" as Format

Dialog {
    id: dialog

    property int afterMin: 360
    property int breakMin: 30
    property string at: ""
    property bool useTime: at !== ""

    canAccept: afterMin > 0 && breakMin > 0

    Column {
        width: parent.width

        DialogHeader { title: qsTr("Break rule") }

        TextField {
            width: parent.width
            label: qsTr("When more than (worked, h:mm)")
            text: Format.duration(dialog.afterMin)
            inputMethodHints: Qt.ImhPreferNumbers | Qt.ImhNoPredictiveText
            onTextChanged: {
                var m = Format.parseDuration(text)
                dialog.afterMin = isNaN(m) || m < 0 ? 0 : m
            }
        }

        TextField {
            width: parent.width
            label: qsTr("Break of at least (minutes, in total)")
            text: String(dialog.breakMin)
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 1; top: 600 }
            onTextChanged: dialog.breakMin = acceptableInput ? Number(text) : 0
        }

        TextSwitch {
            text: qsTr("At an exact time")
            description: qsTr("Put this rule's break at a fixed time of day instead of the general placement")
            checked: dialog.useTime
            onClicked: {
                dialog.useTime = checked
                if (checked && !dialog.at) dialog.at = "12:00"
            }
        }

        ValueButton {
            visible: dialog.useTime
            label: qsTr("Break starts at")
            value: dialog.at
            onClicked: {
                var parts = (dialog.at || "12:00").split(":")
                var picker = pageStack.push("Sailfish.Silica.TimePickerDialog",
                                            { hour: Number(parts[0]), minute: Number(parts[1]),
                                              hourMode: DateTime.TwentyFourHours })
                picker.accepted.connect(function() {
                    dialog.at = Format.pad(picker.hour) + ":" + Format.pad(picker.minute)
                })
            }
        }
    }
}
