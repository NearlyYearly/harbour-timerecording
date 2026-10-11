import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

SettingsBase {
    id: page

    readonly property string year: String(new Date().getFullYear())
    property var holidays: null

    function loadHolidays() {
        backend.run("holidays", [Number(year)], function(h) { page.holidays = h })
    }

    Component.onCompleted: loadHolidays()
    Connections {
        target: backend
        onDataChanged: page.loadHolidays()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Balance & holidays") }

            SectionHeader { text: qsTr("Flexitime") }

            TextSwitch {
                text: qsTr("Count from the first recorded day")
                description: qsTr("Otherwise from a date you choose")
                checked: !!page.values && !page.values["balance.start"]
                onClicked: page.save("balance.start", checked ? "" : backend.status.today)
            }

            ValueButton {
                visible: !!page.values && !!page.values["balance.start"]
                label: qsTr("Count from")
                value: page.values && page.values["balance.start"]
                       ? Format.parseDate(page.values["balance.start"]).toLocaleDateString(Qt.locale(), "d MMM yyyy") : ""
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.DatePickerDialog",
                                                { date: Format.parseDate(page.values["balance.start"]) })
                    picker.accepted.connect(function() { page.save("balance.start", Format.isoDate(picker.date)) })
                }
            }

            DurationField {
                width: parent.width
                signed: true
                label: qsTr("Opening balance (h:mm, may be negative)")
                minutes: page.values ? page.values["balance.opening_min"] : 0
                onCommitted: page.save("balance.opening_min", minutes)
            }

            SectionHeader { text: qsTr("Holidays %1").arg(page.year) }

            TextField {
                width: parent.width
                label: qsTr("Days per year")
                text: page.values ? String(page.values["holiday.entitlement"]) : ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: 0; top: 366; decimals: 1; notation: DoubleValidator.StandardNotation }
                onActiveFocusChanged: if (!activeFocus && acceptableInput)
                    page.save("holiday.entitlement", Number(text.replace(",", ".")))
            }

            TextField {
                width: parent.width
                label: qsTr("Carried over into %1").arg(page.year)
                text: page.values ? String(page.values["holiday.carryover"][page.year] || 0) : ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: -366; top: 366; decimals: 1; notation: DoubleValidator.StandardNotation }
                onActiveFocusChanged: {
                    if (activeFocus || !acceptableInput) return
                    var map = JSON.parse(JSON.stringify(page.values["holiday.carryover"]))
                    map[page.year] = Number(text.replace(",", "."))
                    page.save("holiday.carryover", map)
                }
            }

            DetailRow { label: qsTr("Taken"); value: page.holidays ? String(page.holidays.taken) : "" }
            DetailRow { label: qsTr("Planned"); value: page.holidays ? String(page.holidays.planned) : "" }
            DetailRow {
                label: qsTr("Remaining")
                value: page.holidays ? String(page.holidays.remaining) : ""
                valueColor: page.holidays && page.holidays.remaining < 0 ? Theme.errorColor : Theme.highlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Holidays are counted from day notes. Which day types use holiday days is set under Day types.")
            }
        }
        VerticalScrollDecorator { }
    }
}
