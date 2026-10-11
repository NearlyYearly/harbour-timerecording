import QtQuick 2.6
import "file:///tmp/app/qml/components/Format.js" as Format

// Preview-only: fills sample data, opens every page and saves a screenshot of each.
Item {
    id: smoke

    property string outDir
    property var target
    property int step: 0
    property var steps: []
    readonly property string pages: "file:///tmp/app/qml/pages/"

    function today() { return backend.status.today }

    function shot(name, next) {
        target.grabToImage(function(result) {
            result.saveToFile(outDir + "/" + name + ".png")
            console.log("SMOKE shot", name)
            next()
        })
    }

    function run() {
        if (step >= steps.length) {
            console.log("SMOKE done")
            Qt.quit()
            return
        }
        var s = steps[step++]
        s()
    }

    function later(fn, ms) {
        timer.fn = fn
        timer.interval = ms || 800
        timer.restart()
    }

    function page(name, file, props) {
        return function() {
            // props may be a function so values like today's date are read when the step runs.
            var p = pageStack.push(file.indexOf("Sailfish.") === 0 ? file : pages + file,
                                   (typeof props === "function" ? props() : props) || {})
            later(function() { shot(name, function() { pageStack.pop(); later(run, 300) }) })
        }
    }

    Timer {
        id: timer
        property var fn
        onTriggered: fn()
    }

    Component.onCompleted: {
        var d = function() { return today() }
        steps = [
            function() { later(run, 1500) },
            function() { shot("01-day-empty", run) },
            function() {
                // Yesterday: one long line, checked out -> split by the automatic break.
                var y = Format.addDays(d(), -1)
                backend.mutate("add_task", ["Meetings", "#2196f3"])
                backend.mutate("add_stamp", [{ check_in: y + "T08:00", check_out: y + "T17:15", task_id: 1 }])
                backend.mutate("add_stamp", [{ check_in: d() + "T07:45", check_out: d() + "T12:05", task_id: 1, comment: "Ticket triage" }])
                backend.mutate("add_stamp", [{ check_in: d() + "T12:20", check_out: d() + "T14:00", task_id: 2 }])
                backend.mutate("set_day_note", [d(), -1, "Release day"])
                backend.mutate("set_day_note", [Format.addDays(d(), 3), 1, ""])
                later(run, 1500)
            },
            function() { shot("02-day-lines", run) },
            function() { backend.mutate("punch", [2]); later(run, 1000) },
            function() {
                // Second tap right away must be ignored.
                backend.mutate("punch", [2], function(st) {
                    console.log("SMOKE debounce ignored=" + st.ignored)
                    if (st.ignored) backend.notice("Ignored: you just pressed it.")
                    later(run, 300)
                })
            },
            function() { shot("03-day-running-ignored", run) },
            function() {
                backend.run("day", [d()], function(day) {
                    smoke.line = day.lines[0]
                    backend.run("tasks", [false], function(t) { smoke.tasks = t; run() })
                })
            },
            function() { page("04-edit-line", "EditStampDialog.qml", function() { return { line: smoke.line, date: d(), tasks: smoke.tasks } })() },
            page("05-day-note", "DayNoteDialog.qml", function() { return { date: d(), note: { note_type_id: 1, text: "Beach" } } }),
            page("06-week", "WeekPage.qml", function() { return { date: d() } }),
            page("07-month", "MonthPage.qml", function() { return { date: d() } }),
            page("08-templates", "TemplatesPage.qml", function() { return { date: d(), canSave: true } }),
            page("09-settings", "SettingsPage.qml"),
            page("10-break-rules", "BreakRulesPage.qml"),
            page("11-break-rule-time", "BreakRuleDialog.qml", { afterMin: 360, breakMin: 30, at: "12:00" }),
            page("12-balance", "BalancePage.qml"),
            page("13-day-types", "NoteTypesPage.qml"),
            page("14-day-type", "NoteTypeDialog.qml"),
            page("15-backup", "BackupPage.qml"),
            page("16-tasks", "TasksPage.qml"),
            page("17-rounding", "RoundingPage.qml"),
            page("18-targets", "TargetsPage.qml"),
            function() {
                backend.run("day", [Format.addDays(d(), -1)], function(day) {
                    console.log("SMOKE yesterday lines=" + day.lines.map(function(l) {
                        return l.check_in.substr(11) + "-" + l.check_out.substr(11) + ":" + l.kind }).join(","))
                    run()
                })
            },
            page("18b-reminders", "RemindersPage.qml"),
            function() {
                // Make today's target tiny so "target reached" is due, check every 30 s.
                var key = "target." + ["sun", "mon", "tue", "wed", "thu", "fri", "sat"][new Date().getDay()]
                backend.mutate("set_setting", [key, 60])
                backend.mutate("set_setting", ["remind.interval_sec", 30], function() { later(run, 33000) })
            },
            function() {
                target.parent.grabToImage(function(result) {
                    result.saveToFile(outDir + "/18c-window-cover-notification.png")
                    run()
                })
            },
            function() {
                // Tap the notification: its default action must reach the app's D-Bus receiver.
                var ok = win.__runDefaultAction(win.__toastActions)
                console.log("SMOKE notification tap handled=" + ok + " depth=" + pageStack.depth)
                run()
            },
            function() { backend.mutate("undo"); later(run, 800) },
            function() { shot("19-after-undo", run) },
            page("20-import", "ImportPage.qml"),
            page("21-import-preview", "ImportDialog.qml",
                 { path: "/tmp/smokehome/Documents/timerec.db.gz", name: "timerec.db.gz" }),
            function() {
                backend.mutate("android_import", ["/tmp/smokehome/Documents/timerec.db.gz", true], function(r) {
                    console.log("SMOKE import lines=" + r.lines + " notes=" + r.notes + " tasks=" + r.tasks)
                    backend.run("week", ["2026-01-05"], function(w) {
                        console.log("SMOKE import week delta=" + w.totals.delta_min)
                        run()
                    })
                })
            },
            function() { pageStack.push(pages + "TaskDialog.qml", { task: { id: 5, name: "On call", color: "#009688",
                                                                         work_factor: 0, target_off: 1, holiday_days: 0 } })
                         later(function() { shot("22-task-rules", function() { pageStack.pop(); later(run, 300) }) }) }
        ]
        run()
    }

    property var line
    property var tasks: []
}
