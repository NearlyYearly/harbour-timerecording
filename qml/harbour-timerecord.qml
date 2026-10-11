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

    DBusActivation {
        id: dbus
        onActivated: {
            app.activate()
            // On the day page, jump back to today; never close an open dialog.
            if (pageStack.depth === 1 && pageStack.currentPage.goTo)
                pageStack.currentPage.goTo(backend.status.today)
        }
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
