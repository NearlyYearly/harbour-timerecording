// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

SettingsBase {
    id: page

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                //% "Flexitime"
                title: qsTrId("timerecord-balance-flexitime")
                //% "Balance today %1"
                description: qsTrId("timerecord-balance-balance-today").arg(Format.signedDuration(backend.status.balance_min))
            }

            TextSwitch {
                //% "Count from the first recorded day"
                text: qsTrId("timerecord-balance-count-from-the-first-recorded-day")
                //% "Otherwise from a date you choose"
                description: qsTrId("timerecord-balance-otherwise-from-a-date-you-choose")
                checked: !!page.values && !page.values["balance.start"]
                onClicked: page.save("balance.start", checked ? "" : backend.status.today)
            }

            ValueButton {
                visible: !!page.values && !!page.values["balance.start"]
                //% "Count from"
                label: qsTrId("timerecord-balance-count-from")
                value: page.values && page.values["balance.start"]
                       ? Format.parseDate(page.values["balance.start"]).toLocaleDateString(Qt.locale(), "d MMM yyyy") : ""
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.DatePickerDialog",
                                                { date: Format.parseDate(page.values["balance.start"]) })
                    picker.accepted.connect(function() { page.save("balance.start", Format.isoDate(picker.date)) })
                }
            }

            DurationField {
                width: parent.width
                signed: true
                //% "Opening balance (h:mm, may be negative)"
                label: qsTrId("timerecord-balance-opening-balance-h-mm-may-be")
                minutes: page.values ? page.values["balance.opening_min"] : 0
                onCommitted: page.save("balance.opening_min", minutes)
            }
        }
        VerticalScrollDecorator { }
    }
}
