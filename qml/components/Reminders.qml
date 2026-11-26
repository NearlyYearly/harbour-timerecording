// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Nemo.KeepAlive 1.2
import Nemo.Notifications 1.0
import "Format.js" as Format

// Wakes up regularly (also with the display off while the app runs in the background),
// refreshes the totals and publishes the reminders that are due.
Item {
    // Remote action run when a notification is tapped (see DBusActivation.qml).
    property var action

    // [summary, body] of a due reminder; Python sends its kind and numbers (reminders.py).
    function texts(r) {
        switch (r.kind) {
        case "checkout":
            //% "Still checked in?"
            return [qsTrId("timerecord-reminder-checkout"),
                    //% "Checked in since %1 (%2 h). Did you forget to check out?"
                    qsTrId("timerecord-reminder-checkout-body").arg(r.since).arg(Format.duration(r.length_min))]
        case "target":
            //% "Target reached"
            return [qsTrId("timerecord-reminder-target"),
                    //% "You have worked today's %1 h."
                    qsTrId("timerecord-reminder-target-body").arg(Format.duration(r.target_min))]
        case "checkin":
            //% "Not checked in yet"
            return [qsTrId("timerecord-reminder-checkin"),
                    //% "It is after %1 and you have not checked in today."
                    qsTrId("timerecord-reminder-checkin-body").arg(r.time)]
        case "break":
            //% "Break time"
            return [qsTrId("timerecord-reminder-break"),
                    r.split
                    //% "Break %1–%2. It is booked as check-out and check-in when you check out."
                    ? qsTrId("timerecord-reminder-break-split").arg(r.start).arg(r.end)
                    //% "Break %1–%2. It is deducted automatically."
                    : qsTrId("timerecord-reminder-break-deduct").arg(r.start).arg(r.end)]
        }
        return [r.kind, ""]
    }

    BackgroundJob {
        id: job
        enabled: backend.ready && !!backend.status.remind_enabled
        frequency: backend.status.remind_interval_sec || BackgroundJob.TwoAndHalfMinutes
        triggeredOnEnable: true
        onTriggered: {
            backend.refreshStatus()
            backend.dataChanged()
            backend.run("due_reminders", [], function(list) {
                for (var i = 0; i < list.length; i++) {
                    var t = texts(list[i])
                    var n = notification.createObject(null, { summary: t[0], body: t[1],
                                                              previewSummary: t[0], previewBody: t[1],
                                                              remoteActions: action ? [action] : [] })
                    n.publish()
                }
                job.finished()
            })
        }
    }

    Component {
        id: notification
        Notification {
            //% "Time Recording"
            appName: qsTrId("timerecord-reminders-time-recording")
            appIcon: "harbour-timerecord"
        }
    }
}
