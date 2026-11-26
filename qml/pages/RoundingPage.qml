// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

SettingsBase {
    id: page

    readonly property var steps: [0, 5, 6, 10, 15, 30]
    readonly property var directions: ["nearest", "up", "down"]

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            //% "Rounding"
            PageHeader { title: qsTrId("timerecord-rounding-rounding") }

            Repeater {
                model: page.values ? [
                    //% "Check in"
                    { prefix: "round.in", title: qsTrId("timerecord-rounding-check-in") },
                    //% "Check out"
                    { prefix: "round.out", title: qsTrId("timerecord-rounding-check-out") }
                ] : []

                Column {
                    width: column.width
                    readonly property string prefix: modelData.prefix

                    SectionHeader { text: modelData.title }

                    ComboBox {
                        //% "Round to"
                        label: qsTrId("timerecord-rounding-round-to")
                        currentIndex: Math.max(0, page.steps.indexOf(page.values[prefix + "_step"]))
                        menu: ContextMenu {
                            Repeater {
                                model: page.steps
                                MenuItem {
                                    text: modelData === 0 ? /*% "Off" */ qsTrId("timerecord-rounding-off") : /*% "%1 minutes" */ qsTrId("timerecord-rounding-minutes").arg(modelData)
                                    onClicked: page.save(prefix + "_step", modelData)
                                }
                            }
                        }
                    }

                    ComboBox {
                        visible: page.values[prefix + "_step"] > 1
                        //% "Direction"
                        label: qsTrId("timerecord-rounding-direction")
                        currentIndex: Math.max(0, page.directions.indexOf(page.values[prefix + "_dir"]))
                        menu: ContextMenu {
                            //% "Nearest"
                            MenuItem { text: qsTrId("timerecord-rounding-nearest"); onClicked: page.save(prefix + "_dir", "nearest") }
                            //% "Up"
                            MenuItem { text: qsTrId("timerecord-rounding-up"); onClicked: page.save(prefix + "_dir", "up") }
                            //% "Down"
                            MenuItem { text: qsTrId("timerecord-rounding-down"); onClicked: page.save(prefix + "_dir", "down") }
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                //% "Applies to the check-in/out button. The exact time is kept with each line."
                text: qsTrId("timerecord-rounding-applies-to-the-check-in-out")
            }
        }
        VerticalScrollDecorator { }
    }
}
