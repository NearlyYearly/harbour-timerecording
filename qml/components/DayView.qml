// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "Format.js" as Format

// One day in the pager: header, punch panel (today only), summary and the lines.
SilicaListView {
    id: view

    property string date
    property var page
    property var tasks: []
    property var day: null
    readonly property bool isToday: date === backend.status.today
    readonly property var undoState: backend.status.undo || ({ undo: "", redo: "" })
    // A reload rebuilds the rows and would close an open context menu: wait until it closes.
    property int menusOpen: 0
    property bool stale: false

    onMenusOpenChanged: if (menusOpen === 0 && stale) reload()

    function reload() {
        if (!backend.ready || !date) return
        if (menusOpen > 0) { stale = true; return }
        stale = false
        var requested = date
        backend.run("day", [requested], function(d) { if (view && requested === view.date) view.day = d })
    }

    function editLine(line) {
        pageStack.push(Qt.resolvedUrl("../pages/EditStampDialog.qml"), { line: line, date: date, tasks: tasks })
    }

    // Change one time of a line straight from the context menu; the check-out may pass midnight.
    function changeTime(line, which) {
        var checkIn = Format.parseDateTime(line.check_in)
        var current = Format.parseDateTime(line[which])
        var id = line.id
        var picker = pageStack.push("Sailfish.Silica.TimePickerDialog",
                                    { hour: current.getHours(), minute: current.getMinutes(),
                                      hourMode: DateTime.TwentyFourHours })
        picker.accepted.connect(function() {
            var d = new Date(which === "check_in" ? current : checkIn)
            d.setHours(picker.hour, picker.minute, 0, 0)
            if (which === "check_out" && d < checkIn) d.setDate(d.getDate() + 1)
            var data = {}
            data[which] = Format.isoDateTime(d)
            backend.mutate("update_stamp", [id, data])
        })
    }

    // A forgotten punch: check in (or out) today at a chosen time.
    function punchAt() {
        var now = new Date()
        var picker = pageStack.push("Sailfish.Silica.TimePickerDialog",
                                    { hour: now.getHours(), minute: now.getMinutes(),
                                      hourMode: DateTime.TwentyFourHours })
        var day = date
        picker.accepted.connect(function() {
            var at = Format.parseDate(day)
            at.setHours(picker.hour, picker.minute, 0, 0)
            backend.mutate("punch_at", [Format.isoDateTime(at), backend.optId(backend.status.last_task_id)])
        })
    }

    // The popup belongs to the page, so a reload of the rows does not cancel the delete.
    function deleteLine(line) {
        var id = line.id
        //% "Deleting %1 – %2"
        page.remorse.execute(qsTrId("timerecord-day-view-deleting").arg(Format.time(line.check_in))
                             //% "now"
                             .arg(line.running ? qsTrId("timerecord-day-view-now") : Format.time(line.check_out)),
                             function() { backend.mutate("delete_stamp", [id]) })
    }

    Component.onCompleted: reload()
    onDateChanged: reload()

    Connections {
        target: backend
        onDataChanged: view.reload()
    }

    model: day ? day.lines : []

    PullDownMenu {
        MenuItem {
            //% "Settings"
            text: qsTrId("timerecord-day-view-settings")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/SettingsPage.qml"))
        }
        MenuItem {
            //% "Templates"
            text: qsTrId("timerecord-day-view-templates")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/TemplatesPage.qml"),
                                      { date: view.date, canSave: !!view.day && view.day.lines.filter(function(l) { return l.kind !== "auto_break" && !l.running }).length > 0 })
        }
        MenuItem {
            text: view.day && view.day.note && view.day.note.type_name
                  ? /*% "Day type: %1" */ qsTrId("timerecord-day-view-day-type").arg(view.day.note.type_name) : /*% "Set day type" */ qsTrId("timerecord-day-view-set-day-type")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/DayTypePage.qml"),
                                      { date: view.date, note: view.day ? view.day.note : null })
        }
        MenuItem {
            text: view.day && view.day.note ? /*% "Edit day note" */ qsTrId("timerecord-day-view-edit-day-note") : /*% "Add day note" */ qsTrId("timerecord-day-view-add-day-note")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/DayNoteDialog.qml"),
                                      { date: view.date, note: view.day ? view.day.note : null })
        }
        MenuItem {
            //% "Add line"
            text: qsTrId("timerecord-day-view-add-line")
            onClicked: view.editLine(null)
        }
        MenuItem {
            visible: view.isToday
            text: backend.status.running ? /*% "Check out at…" */ qsTrId("timerecord-day-view-check-out-at") : /*% "Check in at…" */ qsTrId("timerecord-day-view-check-in-at")
            onClicked: view.punchAt()
        }
        MenuItem {
            visible: !view.isToday
            //% "Go to today"
            text: qsTrId("timerecord-day-view-go-to-today")
            onClicked: view.page.goTo(backend.status.today)
        }
        MenuItem {
            visible: view.undoState.redo !== ""
            //% "Redo: %1"
            text: qsTrId("timerecord-day-view-redo").arg(backend.undoName(view.undoState.redo))
            onClicked: backend.mutate("redo")
        }
    }

    // Less frequent pages; the pulley keeps the actions for this day.
    PushUpMenu {
        MenuItem {
            //% "Edit several days"
            text: qsTrId("timerecord-day-view-edit-several-days")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/DaysPage.qml"), { date: view.date })
        }
        MenuItem {
            //% "Vacation"
            text: qsTrId("timerecord-day-view-vacation")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/VacationPage.qml"))
        }
        MenuItem {
            //% "Flexitime"
            text: qsTrId("timerecord-day-view-flexitime")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/BalancePage.qml"))
        }
        MenuItem {
            //% "SPX export"
            text: qsTrId("timerecord-day-view-spx-export")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/SpxExportPage.qml"), { date: view.date })
        }
    }

    header: Column {
        width: view.width
        spacing: Theme.paddingMedium

        BackgroundItem {
            width: parent.width
            height: pageHeader.height
            onClicked: {
                var dialog = pageStack.push("Sailfish.Silica.DatePickerDialog", { date: Format.parseDate(view.date) })
                dialog.accepted.connect(function() { view.page.goTo(Format.isoDate(dialog.date)) })
            }
            PageHeader {
                id: pageHeader
                title: Format.parseDate(view.date).toLocaleDateString(Qt.locale(), "ddd d MMM yyyy")
                description: view.isToday ? /*% "Today" */ qsTrId("timerecord-day-view-today") : /*% "Tap for calendar · swipe for days" */ qsTrId("timerecord-day-view-tap-for-calendar-swipe-for-days")
            }
        }

        PunchPanel {
            visible: view.isToday
            tasks: view.tasks
        }

        BackgroundItem {
            visible: !!(view.day && view.day.note)
            width: parent.width
            height: noteColumn.height + 2 * Theme.paddingMedium
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/DayNoteDialog.qml"),
                                      { date: view.date, note: view.day.note })
            Rectangle {
                anchors.fill: parent
                color: Theme.rgba((view.day && view.day.note && view.day.note.type_color) || Theme.highlightBackgroundColor,
                                  Theme.opacityFaint)
            }
            Column {
                id: noteColumn
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    visible: text.length > 0
                    text: (view.day && view.day.note && view.day.note.type_name) || ""
                    color: Theme.highlightColor
                }
                Label {
                    width: parent.width
                    visible: text.length > 0
                    text: (view.day && view.day.note && view.day.note.text) || ""
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        Row {
            visible: !!view.day
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            readonly property real cell: width / 4
            SummaryCell {
                width: parent.cell
                //% "worked"
                label: qsTrId("timerecord-day-view-worked")
                value: view.day ? Format.duration(view.day.net_min) : ""
            }
            SummaryCell {
                width: parent.cell
                //% "breaks"
                label: qsTrId("timerecord-day-view-breaks")
                value: view.day ? Format.duration(view.day.manual_break_min + view.day.gap_min + view.day.auto_break_min) : ""
                valueColor: Theme.secondaryHighlightColor
            }
            SummaryCell {
                width: parent.cell
                //% "target (credit %1)"
                label: view.day && view.day.credit_min ? qsTrId("timerecord-day-view-target-credit").arg(Format.duration(view.day.credit_min))
                                                       //% "target"
                                                       : qsTrId("timerecord-day-view-target")
                value: view.day ? Format.duration(view.day.target_min) : ""
                valueColor: Theme.secondaryHighlightColor
            }
            SummaryCell {
                width: parent.cell
                //% "day ±"
                label: qsTrId("timerecord-day-view-day")
                value: view.day ? Format.signedDuration(view.day.delta_min) : ""
                valueColor: !view.day || view.day.delta_min >= 0 ? Theme.highlightColor : Theme.errorColor
            }
        }

        Label {
            visible: !!view.day
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryHighlightColor
            //% "Flexitime balance %1"
            text: view.day ? qsTrId("timerecord-day-view-flexitime-balance").arg(Format.signedDuration(view.day.balance_min)) : ""
        }

        SectionHeader {
            //% "Times"
            text: qsTrId("timerecord-day-view-times")
            visible: view.count > 0
        }
    }

    delegate: StampItem {
        line: modelData
        onEditRequested: view.editLine(modelData)
        onTimeRequested: view.changeTime(modelData, which)
        onDeleteRequested: view.deleteLine(modelData)
        onMenuOpenChanged: view.menusOpen += menuOpen ? 1 : -1
        Component.onDestruction: if (menuOpen) view.menusOpen -= 1
        onAutoBreakTapped: pageStack.push(Qt.resolvedUrl("../pages/BreakRulesPage.qml"))
    }

    ViewPlaceholder {
        enabled: !!view.day && view.count === 0 && !view.isToday
        //% "No times"
        text: qsTrId("timerecord-day-view-no-times")
        //% "Pull down to add a line"
        hintText: qsTrId("timerecord-day-view-pull-down-to-add-a-line")
    }

    VerticalScrollDecorator { }
}
