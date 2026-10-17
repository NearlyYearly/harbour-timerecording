// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

// Week overview; swipe for other weeks, tap a day to open it.
Page {
    id: page

    property string date
    property var dayPage
    readonly property int centerIndex: 5000
    readonly property string anchorDate: date || Format.isoDate(new Date())

    ListView {
        id: pager
        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        boundsBehavior: Flickable.StopAtBounds
        model: 2 * page.centerIndex + 1
        currentIndex: page.centerIndex
        cacheBuffer: width
        clip: true

        delegate: SilicaListView {
            id: view
            width: pager.width
            height: pager.height

            property string anyDay: Format.addDays(page.anchorDate, 7 * (index - page.centerIndex))
            property var week: null

            function reload() {
                backend.run("week", [anyDay], function(w) { if (view) view.week = w })
            }
            Component.onCompleted: reload()
            Connections {
                target: backend
                onDataChanged: view.reload()
            }

            model: week ? week.days : []

            header: Column {
                width: view.width
                PageHeader {
                    title: view.week ? qsTr("Week %1").arg(view.week.week) : ""
                    description: view.week
                                 ? Format.parseDate(view.week.start).toLocaleDateString(Qt.locale(), "d MMM") + " – "
                                   + Format.parseDate(view.week.end).toLocaleDateString(Qt.locale(), "d MMM yyyy")
                                 : ""
                }
                Row {
                    visible: !!view.week
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    readonly property real cell: width / 3
                    SummaryCell {
                        width: parent.cell
                        label: qsTr("worked")
                        value: view.week ? Format.duration(view.week.totals.net_min) : ""
                    }
                    SummaryCell {
                        width: parent.cell
                        label: qsTr("target %1").arg(view.week ? Format.duration(view.week.plan_target_min) : "")
                        value: view.week ? Format.signedDuration(view.week.totals.delta_min) : ""
                        valueColor: !view.week || view.week.totals.delta_min >= 0 ? Theme.highlightColor : Theme.errorColor
                    }
                    SummaryCell {
                        width: parent.cell
                        label: qsTr("flexitime")
                        value: view.week ? Format.signedDuration(view.week.balance_min) : ""
                        valueColor: Theme.secondaryHighlightColor
                    }
                }
                SectionHeader { text: qsTr("Days") }
            }

            delegate: BackgroundItem {
                id: row
                height: Theme.itemSizeSmall
                readonly property bool today: modelData.date === backend.status.today
                onClicked: {
                    if (page.dayPage) page.dayPage.goTo(modelData.date)
                    pageStack.pop(page.dayPage)
                }
                Rectangle {
                    visible: !!modelData.note && !!modelData.note.type_color
                    width: Theme.paddingSmall
                    height: parent.height - Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin - Theme.paddingMedium
                    color: modelData.note && modelData.note.type_color ? modelData.note.type_color : Theme.highlightColor
                }
                Column {
                    anchors {
                        left: parent.left; leftMargin: Theme.horizontalPageMargin
                        right: netLabel.left; rightMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: Format.parseDate(modelData.date).toLocaleDateString(Qt.locale(), "ddd d MMM")
                        color: row.today ? Theme.highlightColor : Theme.primaryColor
                        font.bold: row.today
                    }
                    Label {
                        visible: text.length > 0
                        width: parent.width
                        text: modelData.note ? (modelData.note.type_name || modelData.note.text || "") : ""
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                    }
                }
                Label {
                    id: netLabel
                    anchors { right: deltaLabel.left; rightMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                    text: modelData.net_min || modelData.line_count ? Format.duration(modelData.net_min) : "–"
                    color: Theme.primaryColor
                }
                Label {
                    id: deltaLabel
                    width: Theme.itemSizeLarge
                    horizontalAlignment: Text.AlignRight
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                    readonly property bool past: modelData.date <= backend.status.today
                    text: past && (modelData.target_min || modelData.net_min) ? Format.signedDuration(modelData.delta_min) : ""
                    color: modelData.delta_min >= 0 ? Theme.highlightColor : Theme.errorColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            footer: TaskTotals {
                width: view.width
                tasks: view.week ? view.week.tasks : []
            }

            VerticalScrollDecorator { }
        }
    }
}
