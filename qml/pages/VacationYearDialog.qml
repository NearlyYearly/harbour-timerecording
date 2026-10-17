// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Add or edit one year's vacation: days and carryover, plus the days taken that year.
Dialog {
    id: dialog

    property var entry: null      // a row of vacation_years() or null for a new year
    property var years: []
    property var days: []
    readonly property bool isNew: !entry || !entry.own_entry
    readonly property int year: yearField.acceptableInput ? Number(yearField.text) : 0

    function suggestedYear() {
        if (entry) return entry.year
        // Adding goes back in time: one year before the oldest entry.
        var own = years.filter(function(y) { return y.own_entry })
        if (own.length === 0) return new Date().getFullYear()
        return Math.min.apply(null, own.map(function(y) { return y.year })) - 1
    }

    function find(y) {
        for (var i = 0; i < years.length; i++)
            if (years[i].year === y) return years[i]
        return null
    }

    function decimal(field) {
        return Number(field.text.replace(",", "."))
    }

    function loadDays() {
        if (year > 0) backend.run("vacation_days", [year], function(d) { if (dialog) dialog.days = d })
        else dialog.days = []
    }

    // A new year starts with the days it would get anyway and what the year before left.
    function prefill() {
        if (year <= 0 || (entry && entry.own_entry)) return
        backend.run("vacation", [year], function(v) { if (daysField) daysField.text = String(v.days) })
        var previous = find(year - 1)
        carryField.text = String(previous ? Math.round(previous.remaining * 10) / 10 : 0)
    }

    onYearChanged: {
        prefill()
        loadDays()
    }
    Component.onCompleted: {
        if (entry && entry.own_entry) {
            daysField.text = String(entry.days)
            carryField.text = String(entry.carryover)
        }
        yearField.text = String(suggestedYear())
    }

    canAccept: yearField.acceptableInput && daysField.acceptableInput && carryField.acceptableInput
    onAccepted: backend.mutate("set_vacation_year", [year, decimal(daysField), decimal(carryField)])

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader { title: dialog.entry && dialog.entry.own_entry ? qsTr("Vacation %1").arg(dialog.entry.year) : qsTr("Add year") }

            TextField {
                id: yearField
                width: parent.width
                readOnly: !!dialog.entry
                label: qsTr("Year")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1900; top: 2200 }
            }

            TextField {
                id: daysField
                width: parent.width
                label: qsTr("Vacation days")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: 0; top: 366; decimals: 1; notation: DoubleValidator.StandardNotation }
            }

            TextField {
                id: carryField
                width: parent.width
                label: qsTr("Carried over (may be negative)")
                description: {
                    var previous = dialog.find(dialog.year - 1)
                    return previous ? qsTr("%1 days were left at the end of %2").arg(Math.round(previous.remaining * 10) / 10).arg(previous.year) : ""
                }
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: -366; top: 366; decimals: 1; notation: DoubleValidator.StandardNotation }
            }

            SectionHeader {
                text: dialog.days.length > 0 ? qsTr("Taken and planned") : qsTr("No vacation days recorded")
            }

            Repeater {
                model: dialog.days
                DetailItem {
                    label: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd d MMM")
                    value: (modelData.days === 1 ? "" : modelData.days + " · ") + modelData.name
                }
            }
        }

        VerticalScrollDecorator { }
    }
}
