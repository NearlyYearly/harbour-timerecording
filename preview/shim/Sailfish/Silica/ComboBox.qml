import QtQuick 2.6

Column {
    id: combo

    property string label
    property string description
    property int currentIndex: 0
    property var menu: null
    property bool menuOpen: false
    readonly property var currentItem: menu ? menu.items()[currentIndex] || null : null
    property string value: currentItem ? currentItem.text : ""

    function _menuClosed(index) {
        if (index >= 0) currentIndex = index
        menuOpen = false
    }

    // Re-read the value when menu items appear later (Repeater models load async).
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: combo.value = combo.currentItem ? combo.currentItem.text : ""
    }

    onMenuChanged: if (menu) { menu.parent = holder; menu.owner = combo }
    Component.onCompleted: if (menu) { menu.parent = holder; menu.owner = combo }

    width: parent ? parent.width : 0

    BackgroundItem {
        height: Theme.itemSizeSmall + (combo.description ? Theme.fontSizeExtraSmall + Theme.paddingSmall : 0)
        onClicked: combo.menuOpen = !combo.menuOpen
        Row {
            x: Theme.horizontalPageMargin
            y: Theme.paddingLarge
            spacing: Theme.paddingMedium
            Label { text: combo.label; color: Theme.primaryColor }
            Label { text: combo.value; color: Theme.highlightColor }
        }
        Label {
            visible: combo.description.length > 0
            x: Theme.horizontalPageMargin
            y: Theme.itemSizeSmall - Theme.paddingMedium
            width: parent.width - 2 * x
            text: combo.description
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }
    }
    Item {
        id: holder
        width: parent.width
        height: combo.menuOpen && combo.menu ? combo.menu.height : 0
        visible: combo.menuOpen
    }
}
