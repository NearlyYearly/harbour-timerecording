// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "Format.js" as Format

// Big check-in / check-out button with the task picker underneath.
Column {
    id: panel

    property var tasks: []
    readonly property var running: backend.status.running || null

    width: parent.width
    spacing: Theme.paddingMedium

    BackgroundItem {
        id: button
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeHuge
        onClicked: backend.mutate("punch", [backend.optId(taskBox.taskId)], function(st) {
            //% "Ignored: you just pressed it. Wait a few seconds to punch again."
            if (st && st.ignored) backend.notice(qsTrId("timerecord-punch-panel-ignored-you-just-pressed-it-wait"))
        })

        // Checked in: error tint (the action ends the work); checked out: highlight tint.
        Rectangle {
            anchors.fill: parent
            radius: Theme.paddingMedium
            color: Theme.rgba(panel.running ? Theme.errorColor : Theme.highlightBackgroundColor,
                              Theme.highlightBackgroundOpacity)
        }

        Column {
            anchors.centerIn: parent
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: panel.running ? /*% "Check out" */ qsTrId("timerecord-punch-panel-check-out") : /*% "Check in" */ qsTrId("timerecord-punch-panel-check-in")
                font.pixelSize: Theme.fontSizeExtraLarge
                font.family: Theme.fontFamilyHeading
                color: button.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: panel.running
                      //% "since %1 · today %2"
                      ? qsTrId("timerecord-punch-panel-since-today").arg(Format.time(panel.running.check_in))
                                                   .arg(Format.duration(backend.status.today_net_min))
                      //% "today %1 of %2"
                      : qsTrId("timerecord-punch-panel-today-of").arg(Format.duration(backend.status.today_net_min))
                                              .arg(Format.duration(backend.status.today_target_min))
                font.pixelSize: Theme.fontSizeSmall
                color: button.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            }
        }
    }

    TaskComboBox {
        id: taskBox
        tasks: panel.tasks
        taskId: panel.running ? panel.running.task_id : backend.status.last_task_id
        //% "Choosing another task closes the running line and starts a new one"
        description: panel.running ? qsTrId("timerecord-punch-panel-choosing-another-task-closes-the-running") : ""
        onPicked: if (panel.running && value !== panel.running.task_id) backend.mutate("switch_task", [backend.optId(value)])
    }
}
