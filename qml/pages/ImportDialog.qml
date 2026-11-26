// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

// Preview of a Time Recording (Android) backup; accepting imports it as one undo step.
Dialog {
    id: dialog

    property string path
    property string name
    property var preview: null
    property bool withSettings: true

    readonly property var settingNames: ({
        "target.mon": /*% "Target Monday" */ qsTrId("timerecord-import-dialog-target-monday"), "target.tue": /*% "Target Tuesday" */ qsTrId("timerecord-import-dialog-target-tuesday"),
        "target.wed": /*% "Target Wednesday" */ qsTrId("timerecord-import-dialog-target-wednesday"), "target.thu": /*% "Target Thursday" */ qsTrId("timerecord-import-dialog-target-thursday"),
        "target.fri": /*% "Target Friday" */ qsTrId("timerecord-import-dialog-target-friday"), "target.sat": /*% "Target Saturday" */ qsTrId("timerecord-import-dialog-target-saturday"),
        "target.sun": /*% "Target Sunday" */ qsTrId("timerecord-import-dialog-target-sunday"), "break.rules": /*% "Break rules" */ qsTrId("timerecord-import-dialog-break-rules"),
        "break.since": /*% "Automatic breaks from" */ qsTrId("timerecord-import-dialog-automatic-breaks-from"), "balance.start": /*% "Flexitime counted from" */ qsTrId("timerecord-import-dialog-flexitime-counted-from"),
        //% "Opening balance"
        "balance.opening_min": qsTrId("timerecord-import-dialog-opening-balance")
    })

    function settingText(key, value) {
        if (key.indexOf("target.") === 0 || key === "balance.opening_min") return Format.duration(value)
        if (key === "break.rules") return value.map(function(r) {
            //% "> %1 → %2 min"
            return qsTrId("timerecord-import-dialog-min").arg(Format.duration(r.after_min)).arg(r.break_min)
                   //% "at %1"
                   + (r.at ? " " + qsTrId("timerecord-import-dialog-at").arg(r.at) : "")
        }).join(", ")
        return String(value)
    }

    canAccept: !!preview && (preview.lines > 0 || preview.notes > 0 || preview.new_tasks > 0
                             || preview.running.length > 0 || (withSettings && preview.settings.length > 0))

    onAccepted: {
        // The dialog is destroyed before the import returns: keep what the callback needs.
        var bridge = backend
        //% "Imported %1 lines, %2 notes, %3 tasks. Undo removes them again."
        var message = qsTrId("timerecord-import-dialog-imported-lines-notes-tasks-undo-removes")
        bridge.mutate("android_import", [path, withSettings], function(r) {
            bridge.notice(message.arg(r.lines).arg(r.notes).arg(r.tasks))
        })
    }

    Component.onCompleted: backend.run("android_preview", [path], function(p) { if (dialog) dialog.preview = p })

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: dialog.name
                //% "Import"
                acceptText: qsTrId("timerecord-import-dialog-import")
            }

            Label {
                visible: !dialog.preview
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                color: Theme.secondaryHighlightColor
                //% "Reading the backup…"
                text: qsTrId("timerecord-import-dialog-reading-the-backup")
            }

            Column {
                visible: !!dialog.preview
                width: parent.width

                //% "Will be imported"
                SectionHeader { text: qsTrId("timerecord-import-dialog-will-be-imported") }

                DetailItem {
                    //% "Period"
                    label: qsTrId("timerecord-import-dialog-period")
                    value: dialog.preview ? dialog.preview.first + " – " + dialog.preview.last : ""
                }
                DetailItem {
                    //% "Lines"
                    label: qsTrId("timerecord-import-dialog-lines")
                    value: dialog.preview ? String(dialog.preview.lines) : ""
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.running.length > 0
                    //% "Still checked in since"
                    label: qsTrId("timerecord-import-dialog-still-checked-in-since")
                    value: dialog.preview ? dialog.preview.running.replace("T", " ") : ""
                }
                DetailItem {
                    //% "Day notes"
                    label: qsTrId("timerecord-import-dialog-day-notes")
                    value: dialog.preview ? String(dialog.preview.notes) : ""
                }
                DetailItem {
                    //% "New tasks"
                    label: qsTrId("timerecord-import-dialog-new-tasks")
                    value: dialog.preview ? String(dialog.preview.new_tasks) : ""
                }
                DetailItem {
                    //% "Templates"
                    label: qsTrId("timerecord-import-dialog-templates")
                    value: dialog.preview ? String(dialog.preview.templates) : ""
                }
                DetailItem {
                    //% "Vacation years"
                    label: qsTrId("timerecord-import-dialog-vacation-years")
                    value: dialog.preview ? String(dialog.preview.vacation_years) : ""
                }

                SectionHeader {
                    visible: !!dialog.preview && (dialog.preview.skipped_days.length > 0 || dialog.preview.skipped_notes > 0
                                                  || dialog.preview.matched_tasks.length > 0
                                                  || dialog.preview.skipped_years.length > 0)
                    //% "Kept as they are here"
                    text: qsTrId("timerecord-import-dialog-kept-as-they-are-here")
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.skipped_days.length > 0
                    //% "Days that already have lines"
                    label: qsTrId("timerecord-import-dialog-days-that-already-have-lines")
                    value: dialog.preview ? String(dialog.preview.skipped_days.length) : ""
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.skipped_notes > 0
                    //% "Dates that already have a note"
                    label: qsTrId("timerecord-import-dialog-dates-that-already-have-a-note")
                    value: dialog.preview ? String(dialog.preview.skipped_notes) : ""
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.skipped_years.length > 0
                    //% "Vacation years that already have an entry"
                    label: qsTrId("timerecord-import-dialog-vacation-years-that-already-have-an")
                    value: dialog.preview ? dialog.preview.skipped_years.join(", ") : ""
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.matched_tasks.length > 0
                    //% "Tasks with the same name"
                    label: qsTrId("timerecord-import-dialog-tasks-with-the-same-name")
                    value: dialog.preview ? String(dialog.preview.matched_tasks.length) : ""
                }

                SectionHeader {
                    visible: !!dialog.preview && dialog.preview.settings.length > 0
                    //% "Settings"
                    text: qsTrId("timerecord-import-dialog-settings")
                }
                TextSwitch {
                    visible: !!dialog.preview && dialog.preview.settings.length > 0
                    //% "Take over the settings"
                    text: qsTrId("timerecord-import-dialog-take-over-the-settings")
                    //% "Targets, break rules and flexitime carryover. Not undone by undo."
                    description: qsTrId("timerecord-import-dialog-targets-break-rules-and-flexitime-carryover")
                    checked: dialog.withSettings
                    onClicked: dialog.withSettings = checked
                }
                Repeater {
                    model: dialog.preview ? dialog.preview.settings : []
                    DetailItem {
                        opacity: dialog.withSettings ? 1 : Theme.opacityLow
                        label: dialog.settingNames[modelData.key] || modelData.key
                        value: dialog.settingText(modelData.key, modelData["new"])
                    }
                }

                SectionHeader {
                    visible: !!dialog.preview && (dialog.preview.problems.length > 0 || dialog.preview.not_imported.length > 0)
                    //% "Not imported"
                    text: qsTrId("timerecord-import-dialog-not-imported")
                }
                Repeater {
                    model: dialog.preview ? dialog.preview.problems : []
                    Label {
                        x: Theme.horizontalPageMargin
                        width: column.width - 2 * x
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                        text: modelData.date + " " + modelData.time + ": "
                              + (modelData.problem === "check-out without check-in"
                                 ? /*% "check-out without check-in" */ qsTrId("timerecord-import-dialog-check-out-without-check-in") : /*% "check-in without check-out" */ qsTrId("timerecord-import-dialog-check-in-without-check-out"))
                    }
                }
                Repeater {
                    model: dialog.preview ? dialog.preview.not_imported : []
                    Label {
                        x: Theme.horizontalPageMargin
                        width: column.width - 2 * x
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                        text: {
                            switch (modelData.what) {
                            //% "%n weekly target override(s)"
                            case "week_targets": return qsTrId("timerecord-import-dialog-weekly-target-override-s", modelData.value)
                            //% "Punch rounding (%1 min)"
                            case "rounding": return qsTrId("timerecord-import-dialog-punch-rounding-min").arg(modelData.value)
                            //% "%n reminder(s)"
                            case "reminders": return qsTrId("timerecord-import-dialog-reminder-s", modelData.value)
                            //% "%n punch rule(s)"
                            case "punch_rules": return qsTrId("timerecord-import-dialog-punch-rule-s", modelData.value)
                            }
                            return modelData.what
                        }
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                    //% "A backup of the current data is saved to Documents first."
                    text: qsTrId("timerecord-import-dialog-a-backup-of-the-current-data")
                }
            }
        }

        VerticalScrollDecorator { }
    }
}
