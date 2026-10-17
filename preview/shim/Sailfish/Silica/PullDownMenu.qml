// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

// Pulley like Silica: drag the page down from the top, the items appear above the content
// (Qt damps the overshoot, so the content and menu move at about half the finger speed),
// the one nearest the content is highlighted first; releasing selects the highlighted item.
// Clicking the indicator strip opens the menu for mouse use.
// PushUpMenu is the same, mirrored: drag up past the end, the items appear below the content.
Item {
    id: pulley

    default property alias content: column.data
    property bool open: false
    property var flick: null
    property bool __pushUp: false
    readonly property real pull: flick ? Math.max(0, (__pushUp ? 1 : -1) * flick.verticalOvershoot) : 0
    readonly property real step: Theme.itemSizeExtraSmall
    readonly property real startOffset: Theme.paddingLarge * 2
    property int highlightIndex: -1

    function _visibleItems() {
        var list = []
        for (var i = 0; i < column.children.length; i++) {
            var c = column.children[i]
            if (c.__isMenuItem && c.visible) list.push(c)
        }
        return list
    }

    function _menuItemClicked(item) { open = false }

    function _updateHighlight() {
        var items = _visibleItems()
        var index = -1
        if (pull > startOffset && items.length) {
            var fromContent = Math.floor((pull - startOffset) / step)
            index = __pushUp ? Math.min(items.length - 1, fromContent)
                             : Math.max(0, items.length - 1 - fromContent)
        }
        for (var i = 0; i < items.length; i++) items[i]._pullHighlight = (i === index)
        highlightIndex = index
    }

    anchors.fill: parent
    z: 50

    onPullChanged: if (flick && flick.dragging) _updateHighlight()

    Connections {
        target: pulley.flick
        onDraggingChanged: {
            if (pulley.flick.dragging) return
            var items = pulley._visibleItems()
            var chosen = pulley.highlightIndex >= 0 ? items[pulley.highlightIndex] : null
            for (var i = 0; i < items.length; i++) items[i]._pullHighlight = false
            pulley.highlightIndex = -1
            if (chosen) chosen.clicked()
        }
    }

    Component.onCompleted: {
        var f = parent
        while (f && f.contentY === undefined) f = f.parent
        if (f) { parent = f; flick = f }
    }

    // Indicator strip at the top (bottom for push-up), like the glowing pulley line.
    Rectangle {
        y: pulley.__pushUp ? parent.height - height : 0
        width: parent.width
        height: Theme.paddingSmall
        color: Theme.highlightColor
        opacity: stripMouse.pressed || pulley.open ? 0.9 : 0.35
        MouseArea {
            id: stripMouse
            y: pulley.__pushUp ? parent.height - height : 0
            width: parent.width
            height: Theme.paddingLarge * 2
            onClicked: pulley.open = !pulley.open
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: pulley.open
        onClicked: pulley.open = false
    }

    // Menu panel: grows with the pull, the items nearest the content first.
    Rectangle {
        id: panel
        y: pulley.__pushUp ? parent.height - height : 0
        width: parent.width
        height: pulley.open ? column.height : Math.min(Math.max(0, pulley.pull - Theme.paddingLarge), column.height)
        // Stay "visible" at height 0: hidden parents would make every item report visible: false.
        opacity: height > 0 ? 1 : 0
        clip: true
        color: "#f00d2533"
        Column {
            id: column
            width: parent.width
            y: pulley.__pushUp ? 0 : parent.height - height
        }
        Rectangle {
            y: pulley.__pushUp ? 0 : parent.height - height
            width: parent.width
            height: 2
            color: Theme.highlightColor
        }
    }
}
