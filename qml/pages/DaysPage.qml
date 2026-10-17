// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components/Format.js" as Format

// Several days at once: pick a range (a week by default, « » move by its length), tick
// the days, then set or clear their day note or apply a template to all of them.
Page {
    id: page

    property string date
    readonly property int maxDays: 366
    property string from: Format.addDays(date, -((Format.parseDate(date).getDay() + 6) % 7))
    property string to: Format.addDays(from, 6)
    readonly property int length: Format.daysBetween(from, to) + 1
    property var days: []
    property var selected: ({})
    readonly property var dates: {
        var list = []
        for (var i = 0; i < days.length; i++)
            if (selected[days[i].date]) list.push(days[i].date)
        return list
    }

    function setRange(start, end) {
        if (Format.daysBetween(start, end) >= maxDays) end = Format.addDays(start, maxDays - 1)
        from = start
        to = end
    }

    function shift(direction) {
        setRange(Format.addDays(from, direction * length), Format.addDays(to, direction * length))
    }

    // A new range starts with its working days ticked, so weekends get no vacation note.
    function reload(resetSelection) {
        var start = from, end = to
        backend.run("days", [start, end], function(list) {
            if (start !== page.from || end !== page.to) return
            if (resetSelection) {
                var map = {}
                for (var i = 0; i < list.length; i++)
                    if (list[i].target_min > 0) map[list[i].date] = true
                page.selected = map
            }
            page.days = list
        })
    }

    function toggle(day) {
        var map = {}
        for (var k in selected) map[k] = selected[k]
        map[day] = !map[day]
        selected = map
    }

    function selectAll(on) {
        var map = {}
        if (on) for (var i = 0; i < days.length; i++) map[days[i].date] = true
        selected = map
    }

    function pickDate(which) {
        var current = which === "from" ? from : to
        var dialog = pageStack.push("Sailfish.Silica.DatePickerDialog", { date: Format.parseDate(current) })
        dialog.accepted.connect(function() {
            var picked = Format.isoDate(dialog.date)
            var len = page.length
            if (which === "from")
                page.setRange(picked, Format.daysBetween(picked, page.to) >= 0 ? page.to : Format.addDays(picked, len - 1))
            else
                page.setRange(Format.daysBetween(page.from, picked) >= 0 ? page.from : Format.addDays(picked, 1 - len), picked)
        })
    }

    onFromChanged: reload(true)
    onToChanged: reload(true)
    Component.onCompleted: reload(true)

    Connections {
        target: backend
        onDataChanged: page.reload(false)
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.days

        PullDownMenu {
            MenuItem {
                text: page.dates.length < page.days.length ? qsTr("Select all") : qsTr("Select none")
                onClicked: page.selectAll(page.dates.length < page.days.length)
            }
            MenuItem {
                enabled: page.dates.length > 0
                text: qsTr("Clear day notes")
                onClicked: {
                    var n = page.dates.length
                    backend.mutate("set_day_notes", [page.dates, -1, ""], function() {
                        backend.notice(qsTr("Day notes cleared on %n day(s)", "", n))
                    })
                }
            }
            MenuItem {
                enabled: page.dates.length > 0
                text: qsTr("Apply template")
                onClicked: pageStack.push(Qt.resolvedUrl("TemplatesPage.qml"), { date: page.dates[0], dates: page.dates })
            }
            MenuItem {
                enabled: page.dates.length > 0
                text: qsTr("Set day note")
                onClicked: pageStack.push(Qt.resolvedUrl("DayNoteDialog.qml"), { date: page.dates[0], dates: page.dates })
            }
        }

        header: Column {
            width: list.width

            PageHeader {
                title: qsTr("Edit days")
                description: qsTr("%1 of %2 days selected").arg(page.dates.length).arg(page.length)
            }

            Row {
                width: parent.width
                height: Theme.itemSizeSmall
                BackgroundItem {
                    width: Theme.itemSizeMedium
                    height: parent.height
                    onClicked: page.shift(-1)
                    Label {
                        anchors.centerIn: parent
                        text: "«"
                        font.pixelSize: Theme.fontSizeExtraLarge
                        color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                }
                Label {
                    width: parent.width - 2 * Theme.itemSizeMedium
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.highlightColor
                    truncationMode: TruncationMode.Fade
                    text: Format.parseDate(page.from).toLocaleDateString(Qt.locale(), "d MMM") + " – "
                          + Format.parseDate(page.to).toLocaleDateString(Qt.locale(), "d MMM yyyy")
                }
                BackgroundItem {
                    width: Theme.itemSizeMedium
                    height: parent.height
                    onClicked: page.shift(1)
                    Label {
                        anchors.centerIn: parent
                        text: "»"
                        font.pixelSize: Theme.fontSizeExtraLarge
                        color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                }
            }

            ValueButton {
                label: qsTr("From")
                value: Format.parseDate(page.from).toLocaleDateString(Qt.locale(), "ddd d MMM yyyy")
                onClicked: page.pickDate("from")
            }
            ValueButton {
                label: qsTr("To")
                value: Format.parseDate(page.to).toLocaleDateString(Qt.locale(), "ddd d MMM yyyy")
                description: qsTr("« » move by %n day(s)", "", page.length)
                onClicked: page.pickDate("to")
            }

            SectionHeader { text: qsTr("Days") }
        }

        delegate: TextSwitch {
            automaticCheck: false
            checked: !!page.selected[modelData.date]
            text: Format.parseDate(modelData.date).toLocaleDateString(Qt.locale(), "ddd d MMM")
            description: modelData.note ? [modelData.note.type_name || "", modelData.note.text || ""]
                                          .filter(function(s) { return s.length > 0 }).join(" · ")
                                        : ""
            onClicked: page.toggle(modelData.date)
        }

        VerticalScrollDecorator { }
    }
}
