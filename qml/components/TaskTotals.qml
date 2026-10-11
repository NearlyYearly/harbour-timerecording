import QtQuick 2.6
import Sailfish.Silica 1.0
import "Format.js" as Format

// Minutes per task with a proportional bar.
Column {
    id: totals

    property var tasks: []
    readonly property int maxMinutes: tasks.length ? tasks[0].minutes : 0

    SectionHeader {
        visible: totals.tasks.length > 0
        text: qsTr("Tasks")
    }

    Repeater {
        model: totals.tasks
        Item {
            width: totals.width
            height: Theme.itemSizeExtraSmall
            Rectangle {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height - Theme.paddingMedium
                width: totals.maxMinutes ? (parent.width - 2 * Theme.horizontalPageMargin) * modelData.minutes / totals.maxMinutes : 0
                color: Theme.rgba(modelData.color || Theme.highlightBackgroundColor, Theme.opacityLow)
                radius: Theme.paddingSmall
            }
            Label {
                x: Theme.horizontalPageMargin + Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name || qsTr("No task")
            }
            Label {
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin + Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                text: Format.duration(modelData.minutes)
                color: Theme.highlightColor
            }
        }
    }
}
