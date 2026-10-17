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
        failed(lastError)
    }
}
