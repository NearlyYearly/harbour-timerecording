// SPDX-License-Identifier: GPL-3.0-or-later
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

    // First descendant (depth first) for which test(item) is true.
    function find(item, test) {
        if (test(item)) return item
        for (var i = 0; i < item.children.length; i++) {
            var hit = find(item.children[i], test)
            if (hit) return hit
        }
        return null
    }

    function todayView() {
        return find(pageStack.currentPage, function(o) { return o.changeTime !== undefined && o.isToday })
    }

    function row(view, id) {
        return find(view, function(o) { return o.deleteRequested !== undefined && o.line && o.line.id === id })
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
            function() {
                // A new day while yesterday's today is still shown and nothing runs: follow.
                var dayPage = pageStack.currentPage
                var y = Format.addDays(d(), -1)
                dayPage.goTo(y)
                dayPage.seenToday = y
                backend.refreshStatus(function() {
                    later(function() {
                        console.log("SMOKE rollover moved=" + (dayPage.currentDate === d()))
                        run()
                    }, 500)
                })
            },
            function() {
                var menu = find(todayView(), function(o) { return o.__pushUp === true })
                menu.open = true
                later(function() { shot("02b-push-up-menu", function() { menu.open = false; later(run, 300) }) }, 400)
            },
            function() {
                // Forgotten punches at chosen times (yesterday, so never in the future), then undo both.
                var y = Format.addDays(d(), -1)
                backend.mutate("punch_at", [y + "T05:00", 1], function(st) {
                    var inAt = st.running ? st.running.check_in : "none"
                    backend.mutate("punch_at", [y + "T05:30", -1], function(st2) {
                        console.log("SMOKE punch_at in=" + inAt.substr(11) + " out_running=" + !!st2.running)
                        backend.mutate("undo", [], function() { backend.mutate("undo", [], function() { later(run, 500) }) })
                    })
                })
            },
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
                // Checked in: the 30 s refresh must not close an open line menu.
                var view = todayView()
                smoke.line = view.day.lines[0]
                var item = row(view, smoke.line.id)
                item.openMenu()
                backend.dataChanged()
                later(function() {
                    console.log("SMOKE line menu open after refresh=" + row(view, smoke.line.id).menuOpen)
                    shot("03b-line-menu", function() { row(view, smoke.line.id).menuOpen = false; later(run, 500) })
                })
            },
            function() {
                // Change the check-in straight from the menu: 07:45 -> 07:30.
                todayView().changeTime(smoke.line, "check_in")
                later(function() {
                    var picker = pageStack.currentPage
                    picker.hour = 7
                    picker.minute = 30
                    picker.accept()
                    later(function() {
                        console.log("SMOKE changed check-in=" + todayView().day.lines[0].check_in)
                        run()
                    })
                })
            },
            function() {
                // Delete with the page countdown; a refresh in between must not cancel it.
                var view = todayView()
                smoke.count = view.day.lines.length
                view.deleteLine(view.day.lines[1])
                backend.dataChanged()
                later(function() { shot("03c-delete-remorse", function() { later(run, 5500) }) }, 500)
            },
            function() {
                console.log("SMOKE lines before delete=" + smoke.count + " after=" + todayView().day.lines.length)
                backend.mutate("undo", [], function() { backend.mutate("undo", [], function() { later(run, 800) }) })
            },
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
            function() {
                var p = pageStack.push(pages + "DaysPage.qml", { date: d() })
                later(function() {
                    var from = p.from
                    p.shift(1)
                    var shifted = p.from
                    p.shift(-1)
                    console.log("SMOKE days length=" + p.length + " selected=" + p.dates.length
                                + " shift=" + Format.daysBetween(from, shifted) + " back=" + (p.from === from))
                    backend.mutate("set_day_notes", [p.dates, 1, "Trip"], function() {
                        later(function() {
                            var noted = p.days.filter(function(x) { return x.note && x.note.text === "Trip" }).length
                            console.log("SMOKE days noted=" + noted)
                            shot("08b-edit-days", function() {
                                backend.mutate("undo", [], function() { pageStack.pop(); later(run, 300) })
                            })
                        })
                    })
                })
            },
            page("08c-day-note-several", "DayNoteDialog.qml", function() {
                return { date: d(), dates: [d(), Format.addDays(d(), 1), Format.addDays(d(), 2)] } }),
            page("09-settings", "SettingsPage.qml"),
            page("10-break-rules", "BreakRulesPage.qml"),
            page("11-break-rule-time", "BreakRuleDialog.qml", { afterMin: 360, breakMin: 30, at: "12:00" }),
            page("12-balance", "BalancePage.qml"),
            function() {
                var y = new Date().getFullYear()
                backend.mutate("set_vacation_year", [y, 30, 4.5])
                backend.mutate("set_vacation_year", [y - 2, 28, 0])
                later(run, 800)
            },
            page("12b-vacation", "VacationPage.qml"),
            function() {
                backend.run("vacation_years", [], function(years) {
                    smoke.years = years
                    page("12c-vacation-year", "VacationYearDialog.qml", { entry: years[0], years: years })()
                })
            },
            function() { page("12d-vacation-add-year", "VacationYearDialog.qml", { entry: null, years: smoke.years })() },
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
    property int count: 0
    property var years: []
    property var tasks: []
}
