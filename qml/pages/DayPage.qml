import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

// Main page: a horizontal pager of days around the date the app was opened.
Page {
    id: dayPage

    readonly property int centerIndex: 20000
    property string anchorDate: Format.isoDate(new Date())
    property string currentDate: anchorDate
    property var tasks: []

    function goTo(date) {
        pager.currentIndex = centerIndex + Format.daysBetween(anchorDate, date)
        pager.positionViewAtIndex(pager.currentIndex, ListView.Beginning)
    }

    function loadTasks() {
        backend.run("tasks", [false], function(t) { dayPage.tasks = t })
    }

    Connections {
        target: backend
        onReadyChanged: if (backend.ready) { dayPage.anchorDate = backend.status.today; dayPage.goTo(dayPage.anchorDate); dayPage.loadTasks() }
        onDataChanged: dayPage.loadTasks()
    }

    ListView {
        id: pager
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: toolbar.top }
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: width
        model: 2 * dayPage.centerIndex + 1
        currentIndex: dayPage.centerIndex
        clip: true

        onCurrentIndexChanged: dayPage.currentDate = Format.addDays(dayPage.anchorDate, currentIndex - dayPage.centerIndex)

        delegate: DayView {
            width: pager.width
            height: pager.height
            page: dayPage
            tasks: dayPage.tasks
            date: Format.addDays(dayPage.anchorDate, index - dayPage.centerIndex)
        }
    }

    // Bottom bar: overviews for the shown day, and undo of the last change.
    Row {
        id: toolbar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.itemSizeMedium
        readonly property var undoState: backend.status.undo || ({ undo: "", redo: "" })

        ToolbarButton {
            width: parent.width / 3
            text: qsTr("Week")
            onClicked: pageStack.push(Qt.resolvedUrl("WeekPage.qml"), { date: dayPage.currentDate, dayPage: dayPage })
        }
        ToolbarButton {
            width: parent.width / 3
            text: qsTr("Month")
            onClicked: pageStack.push(Qt.resolvedUrl("MonthPage.qml"), { date: dayPage.currentDate, dayPage: dayPage })
        }
        ToolbarButton {
            width: parent.width / 3
            text: qsTr("Undo")
            hint: toolbar.undoState.undo
            enabled: toolbar.undoState.undo !== ""
            onClicked: {
                var label = toolbar.undoState.undo
                backend.mutate("undo", [], function() { backend.notice(qsTr("Undone: %1").arg(label)) })
            }
        }
    }
}
