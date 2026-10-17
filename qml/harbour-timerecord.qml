// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "components"
import "pages"
import "cover"

ApplicationWindow {
    id: app

    property alias backend: backend

    Backend {
        id: backend
        // Silica's own short messages for failed actions and hints.
        onFailed: Notices.show(message, Notice.Long, Notice.Top)
        onNotice: Notices.show(message, Notice.Short, Notice.Top)
    }

    // On the day page, jump back to today; never close an open dialog.
    function showToday() {
        if (pageStack.depth === 1 && pageStack.currentPage.goTo)
            pageStack.currentPage.goTo(backend.status.today)
    }

    // Milliseconds until just after the next local midnight.
    function untilMidnight() {
        var now = new Date()
        var next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 5)
        return next - now
    }

    DBusActivation {
        id: dbus
        onActivated: {
            app.activate()
            app.showToday()
        }
    }

    // Opening the app (also from the launcher or the cover while it runs) shows today.
    Connections {
        target: Qt.application
        onActiveChanged: {
            if (!Qt.application.active || !backend.ready) return
            midnight.arm()
            backend.refreshStatus(function() { app.showToday() })
        }
    }

    // A new day while the app stays open: refresh, the day page may follow (DayPage.qml).
    Timer {
        id: midnight
        function arm() {
            interval = app.untilMidnight()
            restart()
        }
        onTriggered: {
            backend.refreshStatus(function() { backend.dataChanged() })
            arm()
        }
    }

    Connections {
        target: backend
        onReadyChanged: if (backend.ready) midnight.arm()
    }

    Reminders { action: dbus.notificationAction() }

    // Running lines change totals every minute.
    Timer {
        interval: 30000
        repeat: true
        running: backend.ready && !!backend.status.running
        onTriggered: {
            backend.refreshStatus()
            backend.dataChanged()
        }
    }

    initialPage: Component { DayPage { } }
    cover: Component { CoverPage { } }
    allowedOrientations: defaultAllowedOrientations
}
