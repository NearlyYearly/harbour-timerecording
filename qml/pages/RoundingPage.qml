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

            PageHeader { title: qsTr("Rounding") }

            Repeater {
                model: page.values ? [
                    { prefix: "round.in", title: qsTr("Check in") },
                    { prefix: "round.out", title: qsTr("Check out") }
                ] : []

                Column {
                    width: column.width
                    readonly property string prefix: modelData.prefix

                    SectionHeader { text: modelData.title }

                    ComboBox {
                        label: qsTr("Round to")
                        currentIndex: Math.max(0, page.steps.indexOf(page.values[prefix + "_step"]))
                        menu: ContextMenu {
                            Repeater {
                                model: page.steps
                                MenuItem {
                                    text: modelData === 0 ? qsTr("Off") : qsTr("%1 minutes").arg(modelData)
                                    onClicked: page.save(prefix + "_step", modelData)
                                }
                            }
                        }
                    }

                    ComboBox {
                        visible: page.values[prefix + "_step"] > 1
                        label: qsTr("Direction")
                        currentIndex: Math.max(0, page.directions.indexOf(page.values[prefix + "_dir"]))
                        menu: ContextMenu {
                            MenuItem { text: qsTr("Nearest"); onClicked: page.save(prefix + "_dir", "nearest") }
                            MenuItem { text: qsTr("Up"); onClicked: page.save(prefix + "_dir", "up") }
                            MenuItem { text: qsTr("Down"); onClicked: page.save(prefix + "_dir", "down") }
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Applies to the check-in/out button. The exact time is kept with each line.")
            }
        }
        VerticalScrollDecorator { }
    }
}
