import QtQuick 2.6
import QtTest 1.2
import Sailfish.Silica 1.0

// Swipe gestures of the preview page stack (Silica behaviour).
Item {
    id: root
    width: 540
    height: 960

    property alias pageStack: stack
    property string result: ""
    property int taps: 0

    PageStack { id: stack; anchors.fill: parent }

    Component {
        id: plainPage
        Page {
            MouseArea { anchors.fill: parent; onClicked: root.taps++ }
        }
    }
    Component {
        id: dialogPage
        Dialog {
            onAccepted: root.result = "accepted"
            onRejected: root.result = "rejected"
        }
    }
    Component {
        id: pagerPage
        Page {
            ListView {
                anchors.fill: parent
                orientation: ListView.Horizontal
                snapMode: ListView.SnapOneItem
                model: 5
                delegate: Item { width: 540; height: 960 }
            }
        }
    }

    TestCase {
        name: "PageStack"
        when: windowShown

        function init() {
            while (stack.depth > 0) {
                var p = stack.pages[stack.pages.length - 1]
                stack.pages = stack.pages.slice(0, stack.pages.length - 1)
                p.destroy()
            }
            root.result = ""
            root.taps = 0
            stack.push(plainPage)
        }

        function swipe(fromX, dx) {
            var y = 480
            mousePress(root, fromX, y)
            var steps = Math.abs(dx) / 10
            for (var i = 1; i <= steps; i++) mouseMove(root, fromX + (dx > 0 ? 10 : -10) * i, y, 10)
            mouseRelease(root, fromX + dx, y)
            wait(250)
        }

        function test_swipe_right_goes_back() {
            stack.push(plainPage)
            compare(stack.depth, 2)
            swipe(100, 250)
            compare(stack.depth, 1)
            verify(stack.currentPage.visible)
        }

        function test_short_swipe_snaps_back() {
            stack.push(plainPage)
            swipe(100, 60)
            compare(stack.depth, 2)
            compare(stack.currentPage.x, 0)
        }

        function test_swipe_left_on_page_does_nothing() {
            stack.push(plainPage)
            swipe(400, -250)
            compare(stack.depth, 2)
        }

        function test_dialog_swipe_left_accepts() {
            stack.push(dialogPage)
            swipe(400, -250)
            compare(root.result, "accepted")
            compare(stack.depth, 1)
        }

        function test_dialog_swipe_right_cancels() {
            stack.push(dialogPage)
            swipe(100, 250)
            compare(root.result, "rejected")
            compare(stack.depth, 1)
        }

        function test_dialog_cannot_accept() {
            var d = stack.push(dialogPage)
            d.canAccept = false
            swipe(400, -250)
            compare(root.result, "")
            compare(stack.depth, 2)
        }

        function test_taps_reach_the_page() {
            stack.push(plainPage)
            mouseClick(root, 270, 480)
            compare(root.taps, 1)
        }

        function test_sideways_page_swipes_back_from_edge_only() {
            stack.push(pagerPage)
            swipe(200, 250)
            compare(stack.depth, 2)
            wait(500)
            swipe(5, 250)
            compare(stack.depth, 1)
        }
    }
}
