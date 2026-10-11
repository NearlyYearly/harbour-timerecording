import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    SilicaListView {
        anchors.fill: parent
        header: PageHeader { title: qsTr("Settings") }
        model: [
            { title: qsTr("Work time targets"), hint: qsTr("Hours per weekday"), page: "TargetsPage.qml" },
            { title: qsTr("Break rules"), hint: qsTr("Automatic breaks after hours worked"), page: "BreakRulesPage.qml" },
            { title: qsTr("Rounding"), hint: qsTr("Round check-in and check-out times"), page: "RoundingPage.qml" },
            { title: qsTr("Reminders"), hint: qsTr("Forgot to check out, target reached, breaks"), page: "RemindersPage.qml" },
            { title: qsTr("Balance & holidays"), hint: qsTr("Flexitime start, opening balance, holiday entitlement"), page: "BalancePage.qml" },
            { title: qsTr("Tasks"), hint: qsTr("Add, rename, archive"), page: "TasksPage.qml" },
            { title: qsTr("Day types"), hint: qsTr("Vacation, sick, … and how they count"), page: "NoteTypesPage.qml" },
            { title: qsTr("Backup & general"), hint: qsTr("Export, restore, double-tap guard, undo"), page: "BackupPage.qml" },
            { title: qsTr("Import from Android"), hint: qsTr("Time Recording backup (timerec.db.gz)"), page: "ImportPage.qml" }
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
                    color: Theme.secondaryColor
                }
            }
        }
    }
}
