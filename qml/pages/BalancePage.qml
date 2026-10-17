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
                title: qsTr("Flexitime")
                description: qsTr("Balance today %1").arg(Format.signedDuration(backend.status.balance_min))
            }

            TextSwitch {
                text: qsTr("Count from the first recorded day")
                description: qsTr("Otherwise from a date you choose")
                checked: !!page.values && !page.values["balance.start"]
                onClicked: page.save("balance.start", checked ? "" : backend.status.today)
            }

            ValueButton {
                visible: !!page.values && !!page.values["balance.start"]
                label: qsTr("Count from")
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
                label: qsTr("Opening balance (h:mm, may be negative)")
                minutes: page.values ? page.values["balance.opening_min"] : 0
                onCommitted: page.save("balance.opening_min", minutes)
            }
        }
        VerticalScrollDecorator { }
    }
}
