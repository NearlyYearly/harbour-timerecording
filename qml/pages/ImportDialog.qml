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
        "target.mon": qsTr("Target Monday"), "target.tue": qsTr("Target Tuesday"),
        "target.wed": qsTr("Target Wednesday"), "target.thu": qsTr("Target Thursday"),
        "target.fri": qsTr("Target Friday"), "target.sat": qsTr("Target Saturday"),
        "target.sun": qsTr("Target Sunday"), "break.rules": qsTr("Break rules"),
        "break.since": qsTr("Automatic breaks from"), "balance.start": qsTr("Flexitime counted from"),
        "balance.opening_min": qsTr("Opening balance")
    })

    function settingText(key, value) {
        if (key.indexOf("target.") === 0 || key === "balance.opening_min") return Format.duration(value)
        if (key === "break.rules") return value.map(function(r) {
            return qsTr("> %1 → %2 min").arg(Format.duration(r.after_min)).arg(r.break_min)
                   + (r.at ? " " + qsTr("at %1").arg(r.at) : "")
        }).join(", ")
        return String(value)
    }

    canAccept: !!preview && (preview.lines > 0 || preview.notes > 0 || preview.new_tasks > 0
                             || preview.running.length > 0 || (withSettings && preview.settings.length > 0))

    onAccepted: {
        // The dialog is destroyed before the import returns: keep what the callback needs.
        var bridge = backend
        var message = qsTr("Imported %1 lines, %2 notes, %3 tasks. Undo removes them again.")
        bridge.mutate("android_import", [path, withSettings], function(r) {
            bridge.notice(message.arg(r.lines).arg(r.notes).arg(r.tasks))
        })
    }

    Component.onCompleted: backend.run("android_preview", [path], function(p) { dialog.preview = p })

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: dialog.name
                acceptText: qsTr("Import")
            }

            Label {
                visible: !dialog.preview
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                color: Theme.secondaryHighlightColor
                text: qsTr("Reading the backup…")
            }

            Column {
                visible: !!dialog.preview
                width: parent.width

                SectionHeader { text: qsTr("Will be imported") }

                DetailItem {
                    label: qsTr("Period")
                    value: dialog.preview ? dialog.preview.first + " – " + dialog.preview.last : ""
                }
                DetailItem {
                    label: qsTr("Lines")
                    value: dialog.preview ? String(dialog.preview.lines) : ""
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.running.length > 0
                    label: qsTr("Still checked in since")
                    value: dialog.preview ? dialog.preview.running.replace("T", " ") : ""
                }
                DetailItem {
                    label: qsTr("Day notes")
                    value: dialog.preview ? String(dialog.preview.notes) : ""
                }
                DetailItem {
                    label: qsTr("New tasks")
                    value: dialog.preview ? String(dialog.preview.new_tasks) : ""
                }
                DetailItem {
                    label: qsTr("Templates")
                    value: dialog.preview ? String(dialog.preview.templates) : ""
                }
                DetailItem {
                    label: qsTr("Vacation years")
                    value: dialog.preview ? String(dialog.preview.vacation_years) : ""
                }

                SectionHeader {
                    visible: !!dialog.preview && (dialog.preview.skipped_days.length > 0 || dialog.preview.skipped_notes > 0
                                                  || dialog.preview.matched_tasks.length > 0
                                                  || dialog.preview.skipped_years.length > 0)
                    text: qsTr("Kept as they are here")
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.skipped_days.length > 0
                    label: qsTr("Days that already have lines")
                    value: dialog.preview ? String(dialog.preview.skipped_days.length) : ""
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.skipped_notes > 0
                    label: qsTr("Dates that already have a note")
                    value: dialog.preview ? String(dialog.preview.skipped_notes) : ""
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.skipped_years.length > 0
                    label: qsTr("Vacation years that already have an entry")
                    value: dialog.preview ? dialog.preview.skipped_years.join(", ") : ""
                }
                DetailItem {
                    visible: !!dialog.preview && dialog.preview.matched_tasks.length > 0
                    label: qsTr("Tasks with the same name")
                    value: dialog.preview ? String(dialog.preview.matched_tasks.length) : ""
                }

                SectionHeader {
                    visible: !!dialog.preview && dialog.preview.settings.length > 0
                    text: qsTr("Settings")
                }
                TextSwitch {
                    visible: !!dialog.preview && dialog.preview.settings.length > 0
                    text: qsTr("Take over the settings")
                    description: qsTr("Targets, break rules and flexitime carryover. Not undone by undo.")
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
                    text: qsTr("Not imported")
                }
                Repeater {
                    model: dialog.preview ? dialog.preview.problems : []
                    Label {
                        x: Theme.horizontalPageMargin
                        width: column.width - 2 * x
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        text: modelData.date + " " + modelData.time + ": "
                              + (modelData.problem === "check-out without check-in"
                                 ? qsTr("check-out without check-in") : qsTr("check-in without check-out"))
                    }
                }
                Repeater {
                    model: dialog.preview ? dialog.preview.not_imported : []
                    Label {
                        x: Theme.horizontalPageMargin
                        width: column.width - 2 * x
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        text: {
                            switch (modelData.what) {
                            case "week_targets": return qsTr("%n weekly target override(s)", "", modelData.value)
                            case "rounding": return qsTr("Punch rounding (%1 min)").arg(modelData.value)
                            case "reminders": return qsTr("%n reminder(s)", "", modelData.value)
                            case "punch_rules": return qsTr("%n punch rule(s)", "", modelData.value)
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
                    color: Theme.secondaryColor
                    text: qsTr("A backup of the current data is saved to Documents first.")
                }
            }
        }

        VerticalScrollDecorator { }
    }
}
