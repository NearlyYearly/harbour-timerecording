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

        //% "Break rule"
        DialogHeader { title: qsTrId("timerecord-break-rule-dialog-break-rule") }

        TextField {
            width: parent.width
            //% "When more than (worked, h:mm)"
            label: qsTrId("timerecord-break-rule-dialog-when-more-than-worked-h-mm")
            placeholderText: label
            text: Format.duration(dialog.afterMin)
            inputMethodHints: Qt.ImhPreferNumbers | Qt.ImhNoPredictiveText
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: breakField.focus = true
            onTextChanged: {
                var m = Format.parseDuration(text)
                dialog.afterMin = isNaN(m) || m < 0 ? 0 : m
            }
        }

        TextField {
            id: breakField
            width: parent.width
            //% "Break of at least (minutes, in total)"
            label: qsTrId("timerecord-break-rule-dialog-break-of-at-least-minutes-in")
            placeholderText: label
            text: String(dialog.breakMin)
            inputMethodHints: Qt.ImhDigitsOnly
            EnterKey.iconSource: "image://theme/icon-m-enter-close"
            EnterKey.onClicked: focus = false
            validator: IntValidator { bottom: 1; top: 600 }
            onTextChanged: dialog.breakMin = acceptableInput ? Number(text) : 0
        }

        TextSwitch {
            //% "At an exact time"
            text: qsTrId("timerecord-break-rule-dialog-at-an-exact-time")
            //% "Put this rule's break at a fixed time of day instead of the general placement"
            description: qsTrId("timerecord-break-rule-dialog-put-this-rule-s-break-at")
            checked: dialog.useTime
            onClicked: {
                dialog.useTime = checked
                if (checked && !dialog.at) dialog.at = "12:00"
            }
        }

        ValueButton {
            visible: dialog.useTime
            //% "Break starts at"
            label: qsTrId("timerecord-break-rule-dialog-break-starts-at")
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
