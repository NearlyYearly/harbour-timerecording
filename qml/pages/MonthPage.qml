// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

// Month calendar with day totals, month sums, vacation and task totals. Swipe for months.
Page {
    id: page

    property string date
    property var dayPage
    readonly property int centerIndex: 1200
    readonly property var anchor: date ? Format.parseDate(date) : new Date()

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

        delegate: SilicaFlickable {
            id: view
            width: pager.width
            height: pager.height
            contentHeight: column.height + Theme.paddingLarge

            readonly property var first: new Date(page.anchor.getFullYear(), page.anchor.getMonth() + index - page.centerIndex, 1)
            property var month: null

            function reload() {
                backend.run("month", [first.getFullYear(), first.getMonth() + 1], function(m) { if (view) view.month = m })
            }
            Component.onCompleted: reload()
            Connections {
                target: backend
                onDataChanged: view.reload()
            }

            Column {
                id: column
                width: parent.width

                PageHeader {
                    title: view.first.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                }

                Grid {
                    id: grid
                    x: Theme.horizontalPageMargin
                    columns: 7
                    // Spacing (not margins) keeps tinted cells apart.
                    spacing: Theme.paddingSmall
                    readonly property real cell: (view.width - 2 * Theme.horizontalPageMargin - 6 * spacing) / 7
                    readonly property int offset: (view.first.getDay() + 6) % 7

                    Repeater {
                        model: 7
                        Label {
                            width: grid.cell
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryHighlightColor
                        }
                    }
                    Repeater {
                        model: grid.offset
                        Item { width: grid.cell; height: grid.cell }
                    }
                    Repeater {
                        model: view.month ? view.month.days : []
                        BackgroundItem {
                            id: cell
                            width: grid.cell
                            height: grid.cell
                            readonly property bool today: modelData.date === backend.status.today
                            readonly property bool past: modelData.date <= backend.status.today
                            onClicked: {
                                if (page.dayPage) page.dayPage.goTo(modelData.date)
                                pageStack.pop(page.dayPage)
                            }
                            // Day type tint; today gets the platform highlight instead of a ring.
                            Rectangle {
                                visible: cell.today || !!(modelData.note && modelData.note.type_color)
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: cell.today ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                                                  : modelData.note && modelData.note.type_color
                                                    ? Theme.rgba(modelData.note.type_color, Theme.opacityLow)
                                                    : Theme.rgba(Theme.highlightBackgroundColor, 0)
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: Theme.paddingSmall
                                text: Number(modelData.date.substr(8, 2))
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: cell.today
                                color: cell.today ? Theme.highlightColor
                                                  : modelData.target_min ? Theme.primaryColor : Theme.secondaryColor
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Theme.paddingSmall
                                visible: modelData.net_min > 0
                                text: Format.duration(modelData.net_min)
                                font.pixelSize: Theme.fontSizeTiny
                                color: !cell.past ? Theme.secondaryColor
                                       : modelData.delta_min >= 0 ? Theme.highlightColor : Theme.errorColor
                            }
                        }
                    }
                }

                Item { width: parent.width; height: Theme.paddingLarge }

                Row {
                    visible: !!view.month
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    readonly property real cell: width / 3
                    SummaryCell {
                        width: parent.cell
                        label: qsTr("worked")
                        value: view.month ? Format.duration(view.month.totals.net_min) : ""
                    }
                    SummaryCell {
                        width: parent.cell
                        label: qsTr("target %1").arg(view.month ? Format.duration(view.month.plan_target_min) : "")
                        value: view.month ? Format.signedDuration(view.month.totals.delta_min) : ""
                        valueColor: !view.month || view.month.totals.delta_min >= 0 ? Theme.highlightColor : Theme.errorColor
                    }
                    SummaryCell {
                        width: parent.cell
                        label: qsTr("flexitime")
                        value: view.month ? Format.signedDuration(view.month.balance_min) : ""
                        valueColor: Theme.secondaryHighlightColor
                    }
                }

                SectionHeader { text: qsTr("Vacation %1").arg(view.first.getFullYear()) }
                DetailRow {
                    label: qsTr("Taken / planned")
                    value: view.month ? view.month.vacation.taken + " / " + view.month.vacation.planned : ""
                }
                DetailRow {
                    label: qsTr("Remaining")
                    value: view.month ? String(view.month.vacation.remaining) : ""
                    valueColor: view.month && view.month.vacation.remaining < 0 ? Theme.errorColor : Theme.highlightColor
                }

                TaskTotals {
                    width: parent.width
                    tasks: view.month ? view.month.tasks : []
                }
            }
            VerticalScrollDecorator { }
        }
    }
}
