// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import io.thp.pyotherside 1.5

// Single bridge to the Python logic. Every mutating call returns the new status;
// views listen to dataChanged() and reload what they show.
Python {
    id: py

    property bool ready: false
    property var status: ({})
    property string lastError: ""

    signal dataChanged()
    signal failed(string message)
    signal notice(string message)

    // PyOtherSide cannot convert JS null; the API reads -1 as "none".
    function optId(value) {
        return value === null || value === undefined ? -1 : value
    }

    // Python names undo steps and words its errors in English (store.py); these are their
    // translations, keyed by that English (tests/test_translations.py keeps them complete).
    // Anything not listed is shown as it is.
    function undoName(name) {
        var year = /^(.*) (\d{4})$/.exec(name)
        var names = {
            //% "Add day type"
            "Add day type": qsTrId("timerecord-undo-add-day-type"),
            //% "Add line"
            "Add line": qsTrId("timerecord-undo-add-line"),
            //% "Add task"
            "Add task": qsTrId("timerecord-undo-add-task"),
            //% "Apply template"
            "Apply template": qsTrId("timerecord-undo-apply-template"),
            //% "Archive task"
            "Archive task": qsTrId("timerecord-undo-archive-task"),
            //% "Check in"
            "Check in": qsTrId("timerecord-undo-check-in"),
            //% "Check out"
            "Check out": qsTrId("timerecord-undo-check-out"),
            //% "Day note"
            "Day note": qsTrId("timerecord-undo-day-note"),
            //% "Day notes"
            "Day notes": qsTrId("timerecord-undo-day-notes"),
            //% "Delete line"
            "Delete line": qsTrId("timerecord-undo-delete-line"),
            //% "Delete template"
            "Delete template": qsTrId("timerecord-undo-delete-template"),
            //% "Delete vacation %1"
            "Delete vacation %d": qsTrId("timerecord-undo-delete-vacation"),
            //% "Edit day type"
            "Edit day type": qsTrId("timerecord-undo-edit-day-type"),
            //% "Edit line"
            "Edit line": qsTrId("timerecord-undo-edit-line"),
            //% "Edit task"
            "Edit task": qsTrId("timerecord-undo-edit-task"),
            //% "Import from Android"
            "Import from Android": qsTrId("timerecord-undo-import-android"),
            //% "Rename template"
            "Rename template": qsTrId("timerecord-undo-rename-template"),
            //% "Restore task"
            "Restore task": qsTrId("timerecord-undo-restore-task"),
            //% "Save template"
            "Save template": qsTrId("timerecord-undo-save-template"),
            //% "Switch task"
            "Switch task": qsTrId("timerecord-undo-switch-task"),
            //% "Vacation %1"
            "Vacation %d": qsTrId("timerecord-undo-vacation")
        }
        var text = names[year ? year[1] + " %d" : name]
        return text === undefined ? name : year ? text.arg(year[2]) : text
    }

    function errorText(message) {
        var texts = {
            //% "Another line is already running."
            "another line is already running": qsTrId("timerecord-error-line-running"),
            //% "The backup was made by a newer version of the app."
            "backup was made by a newer app version": qsTrId("timerecord-error-backup-newer"),
            //% "A break rule needs the hours worked and a break length."
            "break rule needs after_min >= 0 and break_min > 0": qsTrId("timerecord-error-break-rule"),
            //% "The check-in time is missing."
            "check-in time missing": qsTrId("timerecord-error-check-in-missing"),
            //% "The check-out is before the check-in."
            "check-out is before check-in": qsTrId("timerecord-error-check-out-before"),
            //% "The date must be YYYY-MM-DD."
            "date must be YYYY-MM-DD": qsTrId("timerecord-error-date-format"),
            //% "The number of days is out of range."
            "days out of range": qsTrId("timerecord-error-days-range"),
            //% "The last month is before the first."
            "last month is before the first": qsTrId("timerecord-error-months-order"),
            //% "The name is empty."
            "name is empty": qsTrId("timerecord-error-name-empty"),
            //% "No days are selected."
            "no days selected": qsTrId("timerecord-error-no-days"),
            //% "This is not a Time Recording backup."
            "not a Time Recording backup": qsTrId("timerecord-error-not-backup"),
            //% "The task name is empty."
            "task name is empty": qsTrId("timerecord-error-task-name-empty"),
            //% "The template name is empty."
            "template name is empty": qsTrId("timerecord-error-template-name-empty"),
            //% "The day has no finished lines."
            "the day has no finished lines": qsTrId("timerecord-error-no-finished-lines"),
            //% "The time is in the future."
            "the time is in the future": qsTrId("timerecord-error-future"),
            //% "The time must be HH:MM."
            "time must be HH:MM": qsTrId("timerecord-error-time-format"),
            //% "The type must not be empty."
            "type must not be empty": qsTrId("timerecord-error-type-empty"),
            //% "Unknown kind of line."
            "unknown line kind": qsTrId("timerecord-error-line-kind"),
            //% "The year is out of range."
            "year out of range": qsTrId("timerecord-error-year-range")
        }
        var text = texts[message]
        return text === undefined ? message : text
    }

    function run(name, args, done) {
        py.call("timerecord.api." + name, args || [], function(result) {
            if (done) done(result)
        })
    }

    // Mutation: refresh status and notify all views.
    function mutate(name, args, done) {
        run(name, args, function(result) {
            if (result && result.today !== undefined) status = result
            else refreshStatus()
            dataChanged()
            if (done) done(result)
        })
    }

    function refreshStatus(done) {
        if (ready) run("status", [], function(st) {
            status = st
            if (done) done(st)
        })
    }

    Component.onCompleted: {
        addImportPath(Qt.resolvedUrl("../../python"))
        importModule("timerecord.api", function() {
            py.call("timerecord.api.init",
                    ["~/.local/share/org.timerecord/harbour-timerecord", "~/Documents"],
                    function(st) {
                        status = st
                        ready = true
                        dataChanged()
                    })
        })
    }

    onError: {
        // Python exceptions: keep the message short for the banner.
        var lines = String(traceback).trim().split("\n")
        lastError = lines[lines.length - 1].replace(/^[A-Za-z.]*(Error|Exception): /, "")
        console.warn("python:", traceback)
        failed(errorText(lastError))
    }
}
