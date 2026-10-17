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
        backend.run("day", [requested], function(d) { if (requested === view.date) view.day = d })
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

    // The popup belongs to the page, so a reload of the rows does not cancel the delete.
    function deleteLine(line) {
        var id = line.id
        page.remorse.execute(qsTr("Deleting %1 – %2").arg(Format.time(line.check_in))
                             .arg(line.running ? qsTr("now") : Format.time(line.check_out)),
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
            text: qsTr("Settings")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/SettingsPage.qml"))
        }
        MenuItem {
            text: qsTr("Vacation")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/VacationPage.qml"))
        }
        MenuItem {
            text: qsTr("Edit several days")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/DaysPage.qml"), { date: view.date })
        }
        MenuItem {
            text: qsTr("Templates")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/TemplatesPage.qml"),
                                      { date: view.date, canSave: !!view.day && view.day.lines.filter(function(l) { return l.kind !== "auto_break" && !l.running }).length > 0 })
        }
        MenuItem {
            text: view.day && view.day.note ? qsTr("Edit day note") : qsTr("Add day note")
            onClicked: pageStack.push(Qt.resolvedUrl("../pages/DayNoteDialog.qml"),
                                      { date: view.date, note: view.day ? view.day.note : null })
        }
        MenuItem {
            text: qsTr("Add line")
            onClicked: view.editLine(null)
        }
        MenuItem {
            visible: !view.isToday
            text: qsTr("Go to today")
            onClicked: view.page.goTo(backend.status.today)
        }
        MenuItem {
            visible: view.undoState.redo !== ""
            text: qsTr("Redo: %1").arg(view.undoState.redo)
            onClicked: backend.mutate("redo")
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
                description: view.isToday ? qsTr("Today") : qsTr("Tap for calendar · swipe for days")
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
                label: qsTr("worked")
                value: view.day ? Format.duration(view.day.net_min) : ""
            }
            SummaryCell {
                width: parent.cell
                label: qsTr("breaks")
                value: view.day ? Format.duration(view.day.manual_break_min + view.day.gap_min + view.day.auto_break_min) : ""
                valueColor: Theme.secondaryHighlightColor
            }
            SummaryCell {
                width: parent.cell
                label: view.day && view.day.credit_min ? qsTr("target (credit %1)").arg(Format.duration(view.day.credit_min))
                                                       : qsTr("target")
                value: view.day ? Format.duration(view.day.target_min) : ""
                valueColor: Theme.secondaryHighlightColor
            }
            SummaryCell {
                width: parent.cell
                label: qsTr("day ±")
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
            color: Theme.secondaryColor
            text: view.day ? qsTr("Flexitime balance %1").arg(Format.signedDuration(view.day.balance_min)) : ""
        }

        SectionHeader {
            text: qsTr("Times")
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
        text: qsTr("No times")
        hintText: qsTr("Pull down to add a line")
    }

    VerticalScrollDecorator { }
}
