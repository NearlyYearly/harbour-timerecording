// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import QtTest 1.2
import Sailfish.Silica 1.0

// The preview push-up menu mirrors the pulley: drag up past the end, release on the item.
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

        PushUpMenu {
            id: menu
            MenuItem { text: "Several days"; onClicked: root.chosen = "Several days" }
            MenuItem { text: "Hidden"; visible: false; onClicked: root.chosen = "Hidden" }
            MenuItem { text: "Vacation"; onClicked: root.chosen = "Vacation" }
        }
    }

    TestCase {
        name: "PushUp"
        when: windowShown

        function settle() {
            list.positionViewAtEnd()
            tryCompare(list, "verticalOvershoot", 0, 3000)
            tryCompare(list, "moving", false, 3000)
        }

        function pushAndRelease(distance) {
            settle()
            root.chosen = ""
            var y = 760
            mousePress(list, 270, y)
            // Past the end the list moves at about half the finger speed (Qt damping).
            for (var moved = 0; moved < 2 * distance + 20; moved += 10) {
                y -= 10
                mouseMove(list, 270, y, 10)
            }
            var highlighted = menu.highlightIndex
            mouseRelease(list, 270, y)
            wait(50)
            return highlighted
        }

        function test_short_push_selects_nothing() {
            pushAndRelease(20)
            compare(root.chosen, "")
        }

        function test_push_selects_item_nearest_content_first() {
            pushAndRelease(Theme.paddingLarge * 2 + 30)
            compare(root.chosen, "Several days")
        }

        function test_longer_push_selects_lower_item_and_skips_hidden() {
            pushAndRelease(Theme.paddingLarge * 2 + Theme.itemSizeExtraSmall + 30)
            compare(root.chosen, "Vacation")
        }

        function test_strip_click_opens_menu() {
            settle()
            menu.open = false
            mouseClick(list, 270, root.height - 5)
            verify(menu.open)
            menu.open = false
        }
    }
}
