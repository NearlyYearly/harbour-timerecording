// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

SettingsBase {
    id: page

    readonly property var intervals: [30, 150, 300, 600]
    readonly property bool on: !!values && values["remind.enabled"]

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            //% "Reminders"
            PageHeader { title: qsTrId("timerecord-reminders-reminders") }

            TextSwitch {
                //% "Reminders"
                text: qsTrId("timerecord-reminders-reminders")
                //% "Notifications while the app is running, also in the background or on the cover. Closing the app stops them."
                description: qsTrId("timerecord-reminders-notifications-while-the-app-is-running")
                checked: page.on
                onClicked: page.save("remind.enabled", checked)
            }

            ComboBox {
                visible: page.on
                //% "Check every"
                label: qsTrId("timerecord-reminders-check-every")
                currentIndex: Math.max(0, page.intervals.indexOf(page.values ? page.values["remind.interval_sec"] : 150))
                //% "Shorter is more punctual, longer saves battery"
                description: qsTrId("timerecord-reminders-shorter-is-more-punctual-longer-saves")
                menu: ContextMenu {
                    //% "30 seconds"
                    MenuItem { text: qsTrId("timerecord-reminders-30-seconds"); onClicked: page.save("remind.interval_sec", 30) }
                    //% "2½ minutes"
                    MenuItem { text: qsTrId("timerecord-reminders-2-minutes"); onClicked: page.save("remind.interval_sec", 150) }
                    //% "5 minutes"
                    MenuItem { text: qsTrId("timerecord-reminders-5-minutes"); onClicked: page.save("remind.interval_sec", 300) }
                    //% "10 minutes"
                    MenuItem { text: qsTrId("timerecord-reminders-10-minutes"); onClicked: page.save("remind.interval_sec", 600) }
                }
            }

            SectionHeader { visible: page.on; text: /*% "Remind me" */ qsTrId("timerecord-reminders-remind-me") }

            TextSwitch {
                id: checkoutSwitch
                visible: page.on
                //% "When still checked in after"
                text: qsTrId("timerecord-reminders-when-still-checked-in-after")
                checked: !!page.values && page.values["remind.checkout_after_min"] > 0
                onClicked: page.save("remind.checkout_after_min", checked ? 600 : 0)
            }
            DurationField {
                visible: page.on && checkoutSwitch.checked
                width: parent.width
                //% "Hours checked in without a check-out"
                label: qsTrId("timerecord-reminders-hours-checked-in-without-a-check")
                minutes: page.values ? page.values["remind.checkout_after_min"] : 0
                onCommitted: if (minutes > 0) page.save("remind.checkout_after_min", minutes)
            }

            TextSwitch {
                visible: page.on
                //% "When today's target is reached"
                text: qsTrId("timerecord-reminders-when-today-s-target-is-reached")
                checked: !!page.values && page.values["remind.target_reached"]
                onClicked: page.save("remind.target_reached", checked)
            }

            TextSwitch {
                visible: page.on
                //% "When an automatic break starts"
                text: qsTrId("timerecord-reminders-when-an-automatic-break-starts")
                checked: !!page.values && page.values["remind.break"]
                onClicked: page.save("remind.break", checked)
            }

            TextSwitch {
                id: checkinSwitch
                visible: page.on
                //% "When not checked in by"
                text: qsTrId("timerecord-reminders-when-not-checked-in-by")
                //% "Only on days with a target and without a vacation or sick note"
                description: qsTrId("timerecord-reminders-only-on-days-with-a-target")
                checked: !!page.values && page.values["remind.checkin_time"] !== ""
                onClicked: page.save("remind.checkin_time", checked ? "09:00" : "")
            }
            ValueButton {
                visible: page.on && checkinSwitch.checked
                //% "Time"
                label: qsTrId("timerecord-reminders-time")
                value: page.values ? page.values["remind.checkin_time"] : ""
                onClicked: {
                    var parts = (value || "09:00").split(":")
                    var picker = pageStack.push("Sailfish.Silica.TimePickerDialog",
                                                { hour: Number(parts[0]), minute: Number(parts[1]),
                                                  hourMode: DateTime.TwentyFourHours })
                    picker.accepted.connect(function() {
                        page.save("remind.checkin_time", Format.pad(picker.hour) + ":" + Format.pad(picker.minute))
                    })
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
