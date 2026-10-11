import QtQuick 2.6

Item {
    id: item

    readonly property bool __isMenuItem: true
    property bool _pullHighlight: false
    property alias text: label.text
    property alias color: label.color
    property alias font: label.font

    signal clicked()

    width: parent ? parent.width : 0
    height: visible ? Theme.itemSizeExtraSmall : 0

    Rectangle {
        anchors.fill: parent
        color: Theme.highlightBackgroundColor
        opacity: mouse.pressed || item._pullHighlight ? 0.5 : 0
    }
    Label {
        id: label
        anchors.centerIn: parent
        color: mouse.pressed || item._pullHighlight ? Theme.highlightColor : Theme.primaryColor
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: {
            var p = item.parent
            while (p && p._menuItemClicked === undefined) p = p.parent
            item.clicked()
            if (p) p._menuItemClicked(item)
        }
    }
}
