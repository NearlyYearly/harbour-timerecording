import QtQuick 2.6

// Tap = clicked, press and hold = context menu (inline, below the item) like Silica.
Item {
    id: item

    property real contentHeight: Theme.itemSizeSmall
    property var menu: null
    property bool menuOpen: false
    property var _menuObject: null
    readonly property bool highlighted: mouse.pressed || menuOpen
    default property alias content: contentArea.data

    signal clicked()

    function openMenu() {
        if (!menu) return
        if (!_menuObject) {
            _menuObject = menu.createObject ? menu.createObject(menuHolder) : menu
            _menuObject.parent = menuHolder
            _menuObject.owner = item
        }
        menuOpen = true
    }

    function _menuClosed(index) { menuOpen = false }

    function remorseAction(text, callback, timeout) {
        remorse.callback = callback
        remorse.text = text
        remorse.remaining = (timeout || 4000) / 1000
        remorse.visible = true
        remorseTimer.restart()
    }

    width: parent ? parent.width : 0
    height: contentHeight + (menuOpen && _menuObject ? _menuObject.height : 0)

    Rectangle {
        width: parent.width
        height: item.contentHeight
        color: Theme.highlightBackgroundColor
        opacity: item.highlighted ? 0.4 : 0
    }
    MouseArea {
        id: mouse
        width: parent.width
        height: item.contentHeight
        onClicked: item.menuOpen ? (item.menuOpen = false) : item.clicked()
        onPressAndHold: item.openMenu()
    }
    Item {
        id: contentArea
        width: parent.width
        height: item.contentHeight
    }
    Item {
        id: menuHolder
        y: item.contentHeight
        width: parent.width
        height: item._menuObject ? item._menuObject.height : 0
        visible: item.menuOpen
    }

    Rectangle {
        id: remorse
        property var callback
        property alias text: remorseLabel.text
        property int remaining: 4
        visible: false
        width: parent.width
        height: item.contentHeight
        color: "#ee0d2533"
        z: 10
        Label {
            id: remorseLabel
            anchors.centerIn: parent
            color: Theme.highlightColor
        }
        Label {
            anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
            text: remorse.remaining + "  ✕"
            color: Theme.secondaryColor
        }
        MouseArea {
            anchors.fill: parent
            onClicked: { remorseTimer.stop(); remorse.visible = false }
        }
        Timer {
            id: remorseTimer
            interval: 1000
            repeat: true
            onTriggered: {
                remorse.remaining -= 1
                if (remorse.remaining <= 0) {
                    stop()
                    remorse.visible = false
                    item.menuOpen = false
                    remorse.callback()
                }
            }
        }
    }
}
