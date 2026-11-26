// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

// CSV for SPX (datum;typ;von;bis) of one month or several, with the SPX type per task (D-028).
// Opened from the day page push-up menu.
SettingsBase {
    id: page

    property string date
    // "YYYY-MM"; the last month only counts when several months are chosen.
    property string firstMonth: date.substr(0, 7)
    property string lastMonth: firstMonth
    property bool severalMonths: false
    property var tasks: []
    property string message: ""

    function monthName(month) {
        return Format.parseDate(month + "-01").toLocaleDateString(Qt.locale(), "MMMM yyyy")
    }

    // Any day of the month picks the month.
    function pickMonth(month, done) {
        var picker = pageStack.push("Sailfish.Silica.DatePickerDialog", { date: Format.parseDate(month + "-01") })
        picker.accepted.connect(function() { done(Format.isoDate(picker.date).substr(0, 7)) })
    }

    function pickTime(key) {
        var parts = page.values[key].split(":")
        var picker = pageStack.push("Sailfish.Silica.TimePickerDialog",
                                    { hour: Number(parts[0]), minute: Number(parts[1]),
                                      hourMode: DateTime.TwentyFourHours })
        picker.accepted.connect(function() {
            page.save(key, Format.pad(picker.hour) + ":" + Format.pad(picker.minute))
        })
    }

    function saveTaskType(taskId, text) {
        var types = {}
        var current = page.values["export.spx_task_types"]
        for (var key in current) types[key] = current[key]
        types[String(taskId)] = text
        page.save("export.spx_task_types", types)
    }

    function exportCsv() {
        var last = page.severalMonths ? page.lastMonth : page.firstMonth
        backend.run("export_spx", [page.firstMonth, last], function(result) {
            //% "Saved %n line(s) to %1"
            if (page) page.message = qsTrId("timerecord-spx-export-saved-line-s-to", result.rows).arg(result.path)
        })
    }

    Component.onCompleted: backend.run("tasks", [], function(t) { if (page) page.tasks = t })

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                //% "Export CSV"
                text: qsTrId("timerecord-spx-export-export-csv")
                onClicked: page.exportCsv()
            }
        }

        Column {
            id: column
            width: parent.width

            //% "SPX export"
            PageHeader { title: qsTrId("timerecord-spx-export-spx-export") }

            Label {
                visible: page.message.length > 0
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.WrapAnywhere
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: page.message
            }

            ValueButton {
                label: page.severalMonths ? /*% "From month" */ qsTrId("timerecord-spx-export-from-month") : /*% "Month" */ qsTrId("timerecord-spx-export-month")
                value: page.monthName(page.firstMonth)
                onClicked: page.pickMonth(page.firstMonth, function(m) {
                    page.firstMonth = m
                    if (page.lastMonth < m) page.lastMonth = m
                })
            }

            TextSwitch {
                //% "Several months"
                text: qsTrId("timerecord-spx-export-several-months")
                checked: page.severalMonths
                onClicked: page.severalMonths = checked
            }

            ValueButton {
                visible: page.severalMonths
                //% "Through month"
                label: qsTrId("timerecord-spx-export-through-month")
                value: page.monthName(page.lastMonth)
                onClicked: page.pickMonth(page.lastMonth, function(m) {
                    page.lastMonth = m
                    if (page.firstMonth > m) page.firstMonth = m
                })
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                //% "One line per interval, saved in Documents. Work lines are cut around breaks; days still checked in are left out."
                text: qsTrId("timerecord-spx-export-one-line-per-interval-saved-in")
            }

            //% "SPX types"
            SectionHeader { text: qsTrId("timerecord-spx-export-spx-types") }

            Repeater {
                model: page.values ? [
                    //% "Work"
                    { key: "export.spx_work_type", label: qsTrId("timerecord-spx-export-work") },
                    //% "Breaks"
                    { key: "export.spx_break_type", label: qsTrId("timerecord-spx-export-breaks") }
                ] : []
                TextSettingField {
                    label: modelData.label
                    value: page.values[modelData.key]
                    required: true
                    onCommitted: page.save(modelData.key, entered)
                }
            }

            // A task left empty uses the work type.
            Repeater {
                model: page.values ? page.tasks : []
                TextSettingField {
                    //% "Task: %1"
                    label: qsTrId("timerecord-spx-export-task").arg(modelData.name)
                    // Silica shows the label only with text, so the empty field names the task.
                    //% "%1: %2"
                    placeholderText: qsTrId("timerecord-spx-export-text").arg(modelData.name).arg(page.values["export.spx_work_type"])
                    value: page.values["export.spx_task_types"][String(modelData.id)] || ""
                    onCommitted: page.saveTaskType(modelData.id, entered)
                }
            }

            //% "Business trip"
            SectionHeader { text: qsTrId("timerecord-spx-export-business-trip") }

            TextSettingField {
                visible: !!page.values
                //% "Day type or note"
                label: qsTrId("timerecord-spx-export-day-type-or-note")
                //% "Day type or note (empty = off)"
                placeholderText: qsTrId("timerecord-spx-export-day-type-or-note-empty-off")
                value: page.values ? page.values["export.spx_trip_note"] : ""
                onCommitted: page.save("export.spx_trip_note", entered)
            }

            Repeater {
                model: page.values && page.values["export.spx_trip_note"] ? [
                    //% "Work from"
                    { key: "export.spx_trip_start", label: qsTrId("timerecord-spx-export-work-from") },
                    //% "Break from"
                    { key: "export.spx_trip_break_start", label: qsTrId("timerecord-spx-export-break-from") },
                    //% "Break until"
                    { key: "export.spx_trip_break_end", label: qsTrId("timerecord-spx-export-break-until") },
                    //% "Work until"
                    { key: "export.spx_trip_end", label: qsTrId("timerecord-spx-export-work-until") }
                ] : []
                ValueButton {
                    label: modelData.label
                    value: page.values[modelData.key]
                    onClicked: page.pickTime(modelData.key)
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                //% "Replaces the day's work and breaks. Lines of a task with its own type stay."
                text: qsTrId("timerecord-spx-export-replaces-the-day-s-work-and")
            }

            //% "On-call standby"
            SectionHeader { text: qsTrId("timerecord-spx-export-on-call-standby") }

            TextSettingField {
                visible: !!page.values
                //% "Day type or note"
                label: qsTrId("timerecord-spx-export-day-type-or-note")
                //% "Day type or note (empty = off)"
                placeholderText: qsTrId("timerecord-spx-export-day-type-or-note-empty-off")
                value: page.values ? page.values["export.spx_oncall_note"] : ""
                onCommitted: page.save("export.spx_oncall_note", entered)
            }

            TextSettingField {
                visible: !!page.values && !!page.values["export.spx_oncall_note"]
                //% "SPX type"
                label: qsTrId("timerecord-spx-export-spx-type")
                value: page.values ? page.values["export.spx_oncall_type"] : ""
                required: true
                onCommitted: page.save("export.spx_oncall_type", entered)
            }

            ValueButton {
                visible: !!page.values && !!page.values["export.spx_oncall_note"]
                //% "Handover"
                label: qsTrId("timerecord-spx-export-handover")
                value: page.values ? page.values["export.spx_oncall_handover"] : ""
                onClicked: page.pickTime("export.spx_oncall_handover")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                //% "Mon–Fri from the day's last work to the next day's first work, Sat and Sun from handover to handover. A day without work starts or ends at handover."
                text: qsTrId("timerecord-spx-export-mon-fri-from-the-day-s")
            }
        }
        VerticalScrollDecorator { }
    }
}
