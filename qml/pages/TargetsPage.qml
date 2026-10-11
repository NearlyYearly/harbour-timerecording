// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"
import "../components/Format.js" as Format

SettingsBase {
    id: page

    readonly property var days: [
        { key: "mon", day: 1 }, { key: "tue", day: 2 }, { key: "wed", day: 3 }, { key: "thu", day: 4 },
        { key: "fri", day: 5 }, { key: "sat", day: 6 }, { key: "sun", day: 0 }
    ]

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader { title: qsTr("Work time targets") }

            Repeater {
                model: page.values ? page.days : []
                DurationField {
                    width: column.width
                    label: Qt.locale().dayName(modelData.day, Locale.LongFormat)
                    minutes: page.values["target." + modelData.key]
                    onCommitted: page.save("target." + modelData.key, minutes)
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: page.values
                      ? qsTr("Week: %1").arg(Format.duration(page.days.reduce(function(sum, d) {
                          return sum + page.values["target." + d.key] }, 0)))
                      : ""
            }
        }
        VerticalScrollDecorator { }
    }
}
