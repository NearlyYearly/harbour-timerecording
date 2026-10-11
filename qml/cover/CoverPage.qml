import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components/Format.js" as Format

// Today at a glance: state and task, worked vs. target with a progress bar, day ± and
// flexitime, the next planned break. Actions: check in/out, next task.
CoverBackground {
    id: cover

    readonly property var st: backend.status
    readonly property var running: st.running || null
    readonly property real progress: st.today_target_min > 0 ? Math.min(1, st.today_net_min / st.today_target_min) : 0
    property var tasks: []

    function loadTasks() {
        backend.run("tasks", [false], function(t) { cover.tasks = t })
    }

    function nextTask() {
        if (!tasks.length) return
        var current = running ? running.task_id : st.last_task_id
        var i = 0
        for (; i < tasks.length; i++) if (tasks[i].id === current) break
        var next = tasks[(i + 1) % tasks.length]
        backend.mutate("select_task", [next.id])
    }

    Connections {
        target: backend
        onReadyChanged: if (backend.ready) cover.loadTasks()
        onDataChanged: cover.loadTasks()
    }

    Column {
        x: Theme.paddingLarge
        y: Theme.paddingLarge
        width: parent.width - 2 * x
        spacing: Theme.paddingSmall

        Row {
            spacing: Theme.paddingSmall
            Rectangle {
                width: Theme.paddingMedium
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: cover.running ? Theme.highlightColor : Theme.secondaryColor
            }
            Label {
                text: cover.running ? qsTr("in since %1").arg(Format.time(cover.running.check_in)) : qsTr("checked out")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.highlightColor
            }
        }
        Label {
            width: parent.width
            text: cover.running ? cover.st.running_task_name : qsTr("next: %1").arg(cover.st.last_task_name || "–")
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Format.duration(cover.st.today_net_min || 0)
            font.pixelSize: Theme.fontSizeHuge
            color: cover.running ? Theme.highlightColor : Theme.primaryColor
        }

        Rectangle {
            width: parent.width
            height: Theme.paddingSmall
            radius: height / 2
            color: Theme.rgba(Theme.primaryColor, Theme.opacityFaint)
            Rectangle {
                width: parent.width * cover.progress
                height: parent.height
                radius: parent.radius
                color: Theme.highlightColor
            }
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("of %1 · %2").arg(Format.duration(cover.st.today_target_min || 0))
                                     .arg(Format.signedDuration(cover.st.today_delta_min || 0))
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("flexitime %1").arg(Format.signedDuration(cover.st.balance_min || 0))
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }
        Label {
            visible: !!cover.st.next_break && !!cover.running
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("break %1").arg(cover.st.next_break)
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.highlightColor
            truncationMode: TruncationMode.Fade
        }
    }

    CoverActionList {
        enabled: backend.ready
        CoverAction {
            iconSource: cover.running ? "image://theme/icon-cover-pause" : "image://theme/icon-cover-play"
            onTriggered: backend.mutate("punch", [backend.optId(cover.st.last_task_id)], function(r) {
                if (r && r.ignored) backend.notice(qsTr("Ignored: you just pressed it."))
            })
        }
        CoverAction {
            iconSource: "image://theme/icon-cover-next"
            onTriggered: cover.nextTask()
        }
    }
}
