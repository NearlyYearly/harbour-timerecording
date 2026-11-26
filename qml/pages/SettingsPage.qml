// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    SilicaListView {
        anchors.fill: parent
        //% "Settings"
        header: PageHeader { title: qsTrId("timerecord-settings-settings") }
        model: [
            { title: /*% "Work time targets" */ qsTrId("timerecord-settings-work-time-targets"), hint: /*% "Hours per weekday" */ qsTrId("timerecord-settings-hours-per-weekday"), page: "TargetsPage.qml" },
            { title: /*% "Break rules" */ qsTrId("timerecord-settings-break-rules"), hint: /*% "Automatic breaks after hours worked" */ qsTrId("timerecord-settings-automatic-breaks-after-hours-worked"), page: "BreakRulesPage.qml" },
            { title: /*% "Rounding" */ qsTrId("timerecord-settings-rounding"), hint: /*% "Round check-in and check-out times" */ qsTrId("timerecord-settings-round-check-in-and-check-out"), page: "RoundingPage.qml" },
            { title: /*% "Reminders" */ qsTrId("timerecord-settings-reminders"), hint: /*% "Forgot to check out, target reached, breaks" */ qsTrId("timerecord-settings-forgot-to-check-out-target-reached"), page: "RemindersPage.qml" },
            { title: /*% "Flexitime" */ qsTrId("timerecord-settings-flexitime"), hint: /*% "Counted from, opening balance" */ qsTrId("timerecord-settings-counted-from-opening-balance"), page: "BalancePage.qml" },
            { title: /*% "Tasks" */ qsTrId("timerecord-settings-tasks"), hint: /*% "Add, rename, archive" */ qsTrId("timerecord-settings-add-rename-archive"), page: "TasksPage.qml" },
            { title: /*% "Day types" */ qsTrId("timerecord-settings-day-types"), hint: /*% "Vacation, sick, … and how they count" */ qsTrId("timerecord-settings-vacation-sick-and-how-they-count"), page: "NoteTypesPage.qml" },
            { title: /*% "Backup & general" */ qsTrId("timerecord-settings-backup-general"), hint: /*% "Export, restore, double-tap guard, undo" */ qsTrId("timerecord-settings-export-restore-double-tap-guard-undo"), page: "BackupPage.qml" },
            { title: /*% "Import from Android" */ qsTrId("timerecord-settings-import-from-android"), hint: /*% "Time Recording backup (timerec.db.gz)" */ qsTrId("timerecord-settings-time-recording-backup-timerec-db-gz"), page: "ImportPage.qml" }
        ]
        delegate: BackgroundItem {
            height: Theme.itemSizeMedium
            onClicked: pageStack.push(Qt.resolvedUrl(modelData.page))
            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    text: modelData.title
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    text: modelData.hint
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
