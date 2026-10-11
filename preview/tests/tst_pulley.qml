import QtQuick 2.6
import QtTest 1.2
import Sailfish.Silica 1.0

// The preview pulley must behave like Silica's: pull down, release on the highlighted item.
Item {
    id: root
    width: 540
    height: 960

    property string chosen: ""

    SilicaListView {
        id: list
        anchors.fill: parent
        model: 30
        delegate: Label { text: "row " + index; height: 80 }

        PullDownMenu {
            id: pulley
            MenuItem { text: "Settings"; onClicked: root.chosen = "Settings" }
            MenuItem { text: "Hidden"; visible: false; onClicked: root.chosen = "Hidden" }
            MenuItem { text: "Add line"; onClicked: root.chosen = "Add line" }
            MenuItem { text: "Undo"; onClicked: root.chosen = "Undo" }
        }
    }

    TestCase {
        name: "Pulley"
        when: windowShown

        function settle() {
            tryCompare(list, "verticalOvershoot", 0, 3000)
            tryCompare(list, "moving", false, 3000)
        }

        function pullAndRelease(distance) {
            settle()
            root.chosen = ""
            var y = 200
            mousePress(list, 270, y)
            // The list moves at about half the finger speed past its top (Qt damping), so the
            // finger travels twice the wanted pull, plus the drag threshold.
            for (var moved = 0; moved < 2 * distance + 20; moved += 10) {
                y += 10
                mouseMove(list, 270, y, 10)
            }
            var highlighted = pulley.highlightIndex
            mouseRelease(list, 270, y)
            wait(50)
            return highlighted
        }

        function test_short_pull_selects_nothing() {
            pullAndRelease(20)
            compare(root.chosen, "")
        }

        function test_pull_selects_item_nearest_content_first() {
            pullAndRelease(Theme.paddingLarge * 2 + 30)
            compare(root.chosen, "Undo")
        }

        function test_longer_pull_selects_higher_item_and_skips_hidden() {
            pullAndRelease(Theme.paddingLarge * 2 + Theme.itemSizeExtraSmall + 30)
            compare(root.chosen, "Add line")
            pullAndRelease(Theme.paddingLarge * 2 + 2 * Theme.itemSizeExtraSmall + 30)
            compare(root.chosen, "Settings")
        }

        function test_strip_click_opens_menu() {
            settle()
            pulley.open = false
            mouseClick(list, 270, 5)
            verify(pulley.open)
            pulley.open = false
        }
    }
}
