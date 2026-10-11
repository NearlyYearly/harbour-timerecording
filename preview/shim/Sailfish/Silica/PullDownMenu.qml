// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

// Pulley like Silica: drag the page down from the top, the items appear above the content
// (Qt damps the overshoot, so the content and menu move at about half the finger speed),
// the one nearest the content is highlighted first; releasing selects the highlighted item.
// Clicking the indicator strip opens the menu for mouse use.
Item {
    id: pulley

    default property alias content: column.data
    property bool open: false
    property var flick: null
    readonly property real pull: flick ? Math.max(0, -flick.verticalOvershoot) : 0
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
            var fromBottom = Math.floor((pull - startOffset) / step)
            index = Math.max(0, items.length - 1 - fromBottom)
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

    // Indicator strip at the top, like the glowing pulley line.
    Rectangle {
        width: parent.width
        height: Theme.paddingSmall
        color: Theme.highlightColor
        opacity: stripMouse.pressed || pulley.open ? 0.9 : 0.35
        MouseArea {
            id: stripMouse
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

    // Menu panel: grows with the pull, bottom items first.
    Rectangle {
        id: panel
        width: parent.width
        height: pulley.open ? column.height : Math.min(Math.max(0, pulley.pull - Theme.paddingLarge), column.height)
        // Stay "visible" at height 0: hidden parents would make every item report visible: false.
        opacity: height > 0 ? 1 : 0
        clip: true
        color: "#f00d2533"
        Column {
            id: column
            width: parent.width
            anchors.bottom: parent.bottom
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            color: Theme.highlightColor
        }
    }
}
