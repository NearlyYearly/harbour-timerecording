// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Nemo.KeepAlive 1.2
import Nemo.Notifications 1.0

// Wakes up regularly (also with the display off while the app runs in the background),
// refreshes the totals and publishes the reminders that are due.
Item {
    // Remote action run when a notification is tapped (see DBusActivation.qml).
    property var action

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
                    var n = notification.createObject(null, { summary: list[i].summary, body: list[i].body,
                                                              previewSummary: list[i].summary,
                                                              previewBody: list[i].body,
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
            appName: qsTr("Time Recording")
            appIcon: "harbour-timerecord"
        }
    }
}
