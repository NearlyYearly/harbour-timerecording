// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "Format.js" as Format

// One time line. Tap to edit, hold for the context menu. Auto breaks are computed, not stored.
ListItem {
    id: item

    property var line
    readonly property bool auto: line.kind === "auto_break"
    readonly property bool isBreak: line.kind !== "work"

    signal editRequested()
    signal autoBreakTapped()

    contentHeight: Theme.itemSizeMedium
    menu: auto ? null : contextMenu
    onClicked: auto ? autoBreakTapped() : editRequested()

    Rectangle {
        id: stripe
        width: Theme.paddingSmall
        height: parent.height - Theme.paddingSmall
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.horizontalPageMargin - Theme.paddingMedium
        color: item.isBreak ? Theme.rgba(Theme.secondaryColor, Theme.opacityLow)
                            : (line.task_color || Theme.highlightColor)
    }

    Column {
        anchors {
            left: stripe.right; leftMargin: Theme.paddingMedium
            right: duration.left; rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }
        Label {
            width: parent.width
            text: Format.time(line.check_in) + " – " + (line.running ? qsTr("now") : Format.time(line.check_out))
                  + (line.check_out && line.check_out.substr(0, 10) !== line.check_in.substr(0, 10) ? " +1" : "")
            color: item.highlighted ? Theme.highlightColor : (item.auto ? Theme.secondaryColor : Theme.primaryColor)
            font.italic: item.auto
            truncationMode: TruncationMode.Fade
        }
        Label {
            width: parent.width
            text: item.auto ? (line.planned ? qsTr("Planned break") : qsTr("Automatic break"))
                            : [line.kind === "break" ? qsTr("Break") : line.task_name, line.comment]
                                .filter(function(s) { return !!s }).join(" · ")
            visible: text.length > 0
            font.pixelSize: Theme.fontSizeExtraSmall
            color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }
    }

    Label {
        id: duration
        anchors {
            right: parent.right; rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        text: (item.isBreak ? "−" : "") + Format.duration(line.duration_min)
        color: line.running ? Theme.highlightColor : (item.isBreak ? Theme.secondaryColor : Theme.primaryColor)
        font.italic: item.auto
    }

    Component {
        id: contextMenu
        ContextMenu {
            MenuItem {
                text: qsTr("Edit")
                onClicked: item.editRequested()
            }
            MenuItem {
                text: qsTr("Delete")
                onClicked: {
                    var id = line.id
                    item.remorseAction(qsTr("Deleting"), function() { backend.mutate("delete_stamp", [id]) })
                }
            }
        }
    }
}
