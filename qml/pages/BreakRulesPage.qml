// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

SettingsBase {
    id: page

    readonly property var rules: values ? values["break.rules"] : []
    readonly property string mode: values ? values["break.mode"] : "split"
    readonly property var modes: ["split", "insert", "deduct"]

    function saveRules(list) {
        list.sort(function(a, b) { return a.after_min - b.after_min })
        save("break.rules", list)
    }

    function editRule(index) {
        var rule = index >= 0 ? rules[index] : { after_min: 360, break_min: 30, at: "" }
        var dialog = pageStack.push(Qt.resolvedUrl("BreakRuleDialog.qml"),
                                    { afterMin: rule.after_min, breakMin: rule.break_min, at: rule.at || "" })
        dialog.accepted.connect(function() {
            var list = rules.slice()
            var updated = { after_min: dialog.afterMin, break_min: dialog.breakMin, at: dialog.useTime ? dialog.at : "" }
            if (index >= 0) list[index] = updated
            else list.push(updated)
            saveRules(list)
        })
    }

    function pickTime(current, apply) {
        var parts = (current || "12:00").split(":")
        var picker = pageStack.push("Sailfish.Silica.TimePickerDialog",
                                    { hour: Number(parts[0]), minute: Number(parts[1]),
                                      hourMode: DateTime.TwentyFourHours })
        picker.accepted.connect(function() { apply(Format.pad(picker.hour) + ":" + Format.pad(picker.minute)) })
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.rules

        PullDownMenu {
            MenuItem {
                text: qsTr("Add rule")
                onClicked: page.editRule(-1)
            }
        }

        header: Column {
            width: list.width

            PageHeader { title: qsTr("Break rules") }

            ComboBox {
                label: qsTr("Missing break")
                currentIndex: Math.max(0, page.modes.indexOf(page.mode))
                description: [qsTr("Checks out at the break start and in again at its end. While checked in the break is shown as planned."),
                              qsTr("Shown as a computed break line; the lines stay as they are."),
                              qsTr("Only subtracted from the total.")][currentIndex]
                menu: ContextMenu {
                    MenuItem { text: qsTr("Check out & in"); onClicked: page.save("break.mode", "split") }
                    MenuItem { text: qsTr("Show break line"); onClicked: page.save("break.mode", "insert") }
                    MenuItem { text: qsTr("Deduct only"); onClicked: page.save("break.mode", "deduct") }
                }
            }

            ComboBox {
                visible: page.mode !== "deduct"
                label: qsTr("Place break")
                currentIndex: page.values && page.values["break.placement"] === "fixed" ? 1 : 0
                description: qsTr("Used when a rule has no time of its own")
                menu: ContextMenu {
                    MenuItem { text: qsTr("After hours worked"); onClicked: page.save("break.placement", "after_worked") }
                    MenuItem { text: qsTr("At an exact time"); onClicked: page.save("break.placement", "fixed") }
                }
            }

            DurationField {
                visible: page.mode !== "deduct" && !!page.values && page.values["break.placement"] === "after_worked"
                width: parent.width
                label: qsTr("Start the break after hours worked")
                minutes: page.values ? page.values["break.after_worked_min"] : 0
                onCommitted: page.save("break.after_worked_min", minutes)
            }

            ValueButton {
                visible: page.mode !== "deduct" && !!page.values && page.values["break.placement"] === "fixed"
                label: qsTr("Break starts at")
                value: page.values ? page.values["break.fixed_time"] : ""
                description: qsTr("Falls back to 'after hours worked' when not inside a work line")
                onClicked: page.pickTime(value, function(t) { page.save("break.fixed_time", t) })
            }

            TextSwitch {
                visible: page.mode !== "split"
                text: qsTr("Count gaps as break")
                description: qsTr("Time between check-out and the next check-in on the same day")
                checked: !!page.values && page.values["break.count_gaps"]
                onClicked: page.save("break.count_gaps", checked)
            }

            TextSwitch {
                text: qsTr("Stop at the threshold")
                description: qsTr("Never deduct more than the time beyond the rule threshold (6:10 worked becomes 6:00, not 5:40)")
                checked: !!page.values && page.values["break.cap_at_threshold"]
                onClicked: page.save("break.cap_at_threshold", checked)
            }

            TextSwitch {
                text: qsTr("Apply to all days")
                description: qsTr("Otherwise only from a date on, so imported history keeps its totals")
                checked: !!page.values && !page.values["break.since"]
                onClicked: page.save("break.since", checked ? "" : backend.status.today)
            }

            ValueButton {
                visible: !!page.values && !!page.values["break.since"]
                label: qsTr("Apply from")
                value: page.values && page.values["break.since"]
                       ? Format.parseDate(page.values["break.since"]).toLocaleDateString(Qt.locale(), "d MMM yyyy") : ""
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.DatePickerDialog",
                                                { date: Format.parseDate(page.values["break.since"]) })
                    picker.accepted.connect(function() { page.save("break.since", Format.isoDate(picker.date)) })
                }
            }

            SectionHeader { text: qsTr("Rules") }
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            onClicked: page.editRule(index)
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: {
                        var i = index
                        item.remorseAction(qsTr("Deleting"), function() {
                            var list = page.rules.slice()
                            list.splice(i, 1)
                            page.saveRules(list)
                        })
                    }
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("> %1 → %2 min").arg(Format.duration(modelData.after_min)).arg(modelData.break_min)
                      + (modelData.at ? " " + qsTr("at %1").arg(modelData.at) : "")
                color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                truncationMode: TruncationMode.Fade
            }
        }

        footer: Item {
            width: list.width
            height: footerLabel.height + 2 * Theme.paddingLarge
            Label {
                id: footerLabel
                x: Theme.horizontalPageMargin
                y: Theme.paddingLarge
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Breaks are cumulative: with 6:00 → 30 min and 9:00 → 45 min, a long day gets 30 minutes at the first rule's time and 15 more at the second rule's time.")
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0 && !!page.values
            text: qsTr("No break rules")
            hintText: qsTr("Pull down to add one")
        }

        VerticalScrollDecorator { }
    }
}
