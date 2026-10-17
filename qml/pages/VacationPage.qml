// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

// Vacation per year: days, carryover, taken, planned, left. Opened from the day page push-up menu.
Page {
    id: page

    property var years: []
    property var values: null
    readonly property var current: years.length > 0 ? years.filter(function(y) { return y.year === new Date().getFullYear() })[0] : null

    function load() {
        backend.run("vacation_years", [], function(y) { page.years = y })
        backend.run("get_settings", [], function(v) { page.values = v })
    }

    function number(n) {
        return String(Math.round(n * 10) / 10)
    }

    function editYear(entry) {
        pageStack.push(Qt.resolvedUrl("VacationYearDialog.qml"), { entry: entry, years: page.years })
    }

    Component.onCompleted: load()
    Connections {
        target: backend
        onDataChanged: page.load()
    }

    RemorsePopup { id: remorse }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.years

        PullDownMenu {
            MenuItem {
                text: qsTr("Add year")
                onClicked: page.editYear(null)
            }
        }

        header: Column {
            width: list.width

            PageHeader { title: qsTr("Vacation") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Theme.fontSizeHuge
                color: page.current && page.current.remaining < 0 ? Theme.errorColor : Theme.highlightColor
                text: page.current ? page.number(page.current.remaining) : ""
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignRight
                color: Theme.secondaryHighlightColor
                text: page.current ? qsTr("days left in %1").arg(page.current.year) : ""
            }

            SectionHeader { text: qsTr("Years") }
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeMedium
            onClicked: page.editYear(modelData)
            menu: modelData.own_entry ? deleteMenu : null

            Component {
                id: deleteMenu
                ContextMenu {
                    MenuItem {
                        text: qsTr("Delete entry")
                        onClicked: {
                            var year = modelData.year
                            item.remorseAction(qsTr("Deleting"), function() {
                                backend.mutate("delete_vacation_year", [year])
                            })
                        }
                    }
                }
            }

            Label {
                id: yearLabel
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontSizeLarge
                color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                text: modelData.year
            }
            Column {
                anchors {
                    left: yearLabel.right; leftMargin: Theme.paddingLarge
                    right: leftLabel.left; rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeSmall
                    color: modelData.own_entry ? Theme.primaryColor : Theme.secondaryColor
                    text: modelData.carryover !== 0
                          ? qsTr("%1 + %2 days").arg(page.number(modelData.days)).arg(page.number(modelData.carryover))
                          : qsTr("%1 days").arg(page.number(modelData.days))
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: (modelData.planned > 0
                           ? qsTr("%1 taken · %2 planned").arg(page.number(modelData.taken)).arg(page.number(modelData.planned))
                           : qsTr("%1 taken").arg(page.number(modelData.taken)))
                          + (modelData.own_entry ? "" : " · " + qsTr("no entry"))
                }
            }
            Label {
                id: leftLabel
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                font.pixelSize: Theme.fontSizeLarge
                color: modelData.remaining < 0 ? Theme.errorColor : Theme.highlightColor
                text: page.number(modelData.remaining)
            }
        }

        footer: Column {
            width: list.width
            spacing: Theme.paddingMedium

            TextField {
                width: parent.width
                label: qsTr("Days for a year without an entry")
                description: qsTr("Used when no earlier year has an entry to copy")
                text: page.values ? String(page.values["vacation.default_days"]) : ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: 0; top: 366; decimals: 1; notation: DoubleValidator.StandardNotation }
                onActiveFocusChanged: if (!activeFocus && acceptableInput)
                    backend.mutate("set_setting", ["vacation.default_days", Number(text.replace(",", "."))])
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Days + carried over. Vacation is counted from day types and tasks that use vacation days (Settings → Day types, Tasks). A year without an entry gets the days of the latest earlier year and no carryover.")
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}
