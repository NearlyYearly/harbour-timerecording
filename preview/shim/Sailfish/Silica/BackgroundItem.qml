import QtQuick 2.6

Item {
    id: item

    readonly property bool highlighted: mouse.pressed
    default property alias content: contentArea.data

    signal clicked()
    signal pressAndHold()

    width: parent ? parent.width : 0
    height: Theme.itemSizeSmall

    Rectangle {
        anchors.fill: parent
        color: Theme.highlightBackgroundColor
        opacity: item.highlighted ? 0.4 : 0
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: item.clicked()
        onPressAndHold: item.pressAndHold()
    }
    Item {
        id: contentArea
        anchors.fill: parent
    }
}
