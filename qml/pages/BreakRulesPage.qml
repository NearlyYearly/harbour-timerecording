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
                //% "Add rule"
                text: qsTrId("timerecord-break-rules-add-rule")
                onClicked: page.editRule(-1)
            }
        }

        header: Column {
            width: list.width

            //% "Break rules"
            PageHeader { title: qsTrId("timerecord-break-rules-break-rules") }

            ComboBox {
                //% "Missing break"
                label: qsTrId("timerecord-break-rules-missing-break")
                currentIndex: Math.max(0, page.modes.indexOf(page.mode))
                //% "Checks out at the break start and in again at its end. While checked in the break is shown as planned."
                description: [qsTrId("timerecord-break-rules-checks-out-at-the-break-start"),
                              //% "Shown as a computed break line; the lines stay as they are."
                              qsTrId("timerecord-break-rules-shown-as-a-computed-break-line"),
                              //% "Only subtracted from the total."
                              qsTrId("timerecord-break-rules-only-subtracted-from-the-total")][currentIndex]
                menu: ContextMenu {
                    //% "Check out & in"
                    MenuItem { text: qsTrId("timerecord-break-rules-check-out-in"); onClicked: page.save("break.mode", "split") }
                    //% "Show break line"
                    MenuItem { text: qsTrId("timerecord-break-rules-show-break-line"); onClicked: page.save("break.mode", "insert") }
                    //% "Deduct only"
                    MenuItem { text: qsTrId("timerecord-break-rules-deduct-only"); onClicked: page.save("break.mode", "deduct") }
                }
            }

            ComboBox {
                visible: page.mode !== "deduct"
                //% "Place break"
                label: qsTrId("timerecord-break-rules-place-break")
                currentIndex: page.values && page.values["break.placement"] === "fixed" ? 1 : 0
                //% "Used when a rule has no time of its own"
                description: qsTrId("timerecord-break-rules-used-when-a-rule-has-no")
                menu: ContextMenu {
                    //% "After hours worked"
                    MenuItem { text: qsTrId("timerecord-break-rules-after-hours-worked"); onClicked: page.save("break.placement", "after_worked") }
                    //% "At an exact time"
                    MenuItem { text: qsTrId("timerecord-break-rules-at-an-exact-time"); onClicked: page.save("break.placement", "fixed") }
                }
            }

            DurationField {
                visible: page.mode !== "deduct" && !!page.values && page.values["break.placement"] === "after_worked"
                width: parent.width
                //% "Start the break after hours worked"
                label: qsTrId("timerecord-break-rules-start-the-break-after-hours-worked")
                minutes: page.values ? page.values["break.after_worked_min"] : 0
                onCommitted: page.save("break.after_worked_min", minutes)
            }

            ValueButton {
                visible: page.mode !== "deduct" && !!page.values && page.values["break.placement"] === "fixed"
                //% "Break starts at"
                label: qsTrId("timerecord-break-rules-break-starts-at")
                value: page.values ? page.values["break.fixed_time"] : ""
                //% "Falls back to 'after hours worked' when not inside a work line"
                description: qsTrId("timerecord-break-rules-falls-back-to-after-hours-worked")
                onClicked: page.pickTime(value, function(t) { page.save("break.fixed_time", t) })
            }

            TextSwitch {
                visible: page.mode !== "split"
                //% "Count gaps as break"
                text: qsTrId("timerecord-break-rules-count-gaps-as-break")
                //% "Time between check-out and the next check-in on the same day"
                description: qsTrId("timerecord-break-rules-time-between-check-out-and-the")
                checked: !!page.values && page.values["break.count_gaps"]
                onClicked: page.save("break.count_gaps", checked)
            }

            TextSwitch {
                //% "Stop at the threshold"
                text: qsTrId("timerecord-break-rules-stop-at-the-threshold")
                //% "Never deduct more than the time beyond the rule threshold (6:10 worked becomes 6:00, not 5:40)"
                description: qsTrId("timerecord-break-rules-never-deduct-more-than-the-time")
                checked: !!page.values && page.values["break.cap_at_threshold"]
                onClicked: page.save("break.cap_at_threshold", checked)
            }

            TextSwitch {
                //% "Apply to all days"
                text: qsTrId("timerecord-break-rules-apply-to-all-days")
                //% "Otherwise only from a date on, so imported history keeps its totals"
                description: qsTrId("timerecord-break-rules-otherwise-only-from-a-date-on")
                checked: !!page.values && !page.values["break.since"]
                onClicked: page.save("break.since", checked ? "" : backend.status.today)
            }

            ValueButton {
                visible: !!page.values && !!page.values["break.since"]
                //% "Apply from"
                label: qsTrId("timerecord-break-rules-apply-from")
                value: page.values && page.values["break.since"]
                       ? Format.parseDate(page.values["break.since"]).toLocaleDateString(Qt.locale(), "d MMM yyyy") : ""
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.DatePickerDialog",
                                                { date: Format.parseDate(page.values["break.since"]) })
                    picker.accepted.connect(function() { page.save("break.since", Format.isoDate(picker.date)) })
                }
            }

            //% "Rules"
            SectionHeader { text: qsTrId("timerecord-break-rules-rules") }
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            onClicked: page.editRule(index)
            menu: ContextMenu {
                MenuItem {
                    //% "Delete"
                    text: qsTrId("timerecord-break-rules-delete")
                    onClicked: {
                        var i = index
                        //% "Deleting"
                        item.remorseAction(qsTrId("timerecord-break-rules-deleting"), function() {
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
                //% "> %1 → %2 min"
                text: qsTrId("timerecord-break-rules-min").arg(Format.duration(modelData.after_min)).arg(modelData.break_min)
                      //% "at %1"
                      + (modelData.at ? " " + qsTrId("timerecord-break-rules-at").arg(modelData.at) : "")
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
                color: Theme.secondaryHighlightColor
                //% "Breaks are cumulative: with 6:00 → 30 min and 9:00 → 45 min, a long day gets 30 minutes at the first rule's time and 15 more at the second rule's time."
                text: qsTrId("timerecord-break-rules-breaks-are-cumulative-with-6-00")
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0 && !!page.values
            //% "No break rules"
            text: qsTrId("timerecord-break-rules-no-break-rules")
            //% "Pull down to add one"
            hintText: qsTrId("timerecord-break-rules-pull-down-to-add-one")
        }

        VerticalScrollDecorator { }
    }
}
