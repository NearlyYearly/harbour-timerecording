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

            PageHeader { title: qsTr("Reminders") }

            TextSwitch {
                text: qsTr("Reminders")
                description: qsTr("Notifications while the app is running, also in the background or on the cover. Closing the app stops them.")
                checked: page.on
                onClicked: page.save("remind.enabled", checked)
            }

            ComboBox {
                visible: page.on
                label: qsTr("Check every")
                currentIndex: Math.max(0, page.intervals.indexOf(page.values ? page.values["remind.interval_sec"] : 150))
                description: qsTr("Shorter is more punctual, longer saves battery")
                menu: ContextMenu {
                    MenuItem { text: qsTr("30 seconds"); onClicked: page.save("remind.interval_sec", 30) }
                    MenuItem { text: qsTr("2½ minutes"); onClicked: page.save("remind.interval_sec", 150) }
                    MenuItem { text: qsTr("5 minutes"); onClicked: page.save("remind.interval_sec", 300) }
                    MenuItem { text: qsTr("10 minutes"); onClicked: page.save("remind.interval_sec", 600) }
                }
            }

            SectionHeader { visible: page.on; text: qsTr("Remind me") }

            TextSwitch {
                id: checkoutSwitch
                visible: page.on
                text: qsTr("When still checked in after")
                checked: !!page.values && page.values["remind.checkout_after_min"] > 0
                onClicked: page.save("remind.checkout_after_min", checked ? 600 : 0)
            }
            DurationField {
                visible: page.on && checkoutSwitch.checked
                width: parent.width
                label: qsTr("Hours checked in without a check-out")
                minutes: page.values ? page.values["remind.checkout_after_min"] : 0
                onCommitted: if (minutes > 0) page.save("remind.checkout_after_min", minutes)
            }

            TextSwitch {
                visible: page.on
                text: qsTr("When today's target is reached")
                checked: !!page.values && page.values["remind.target_reached"]
                onClicked: page.save("remind.target_reached", checked)
            }

            TextSwitch {
                visible: page.on
                text: qsTr("When an automatic break starts")
                checked: !!page.values && page.values["remind.break"]
                onClicked: page.save("remind.break", checked)
            }

            TextSwitch {
                id: checkinSwitch
                visible: page.on
                text: qsTr("When not checked in by")
                description: qsTr("Only on days with a target and without a vacation or sick note")
                checked: !!page.values && page.values["remind.checkin_time"] !== ""
                onClicked: page.save("remind.checkin_time", checked ? "09:00" : "")
            }
            ValueButton {
                visible: page.on && checkinSwitch.checked
                label: qsTr("Time")
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
