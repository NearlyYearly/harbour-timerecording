import QtQuick 2.6

Rectangle {
    id: popup

    property var callback
    property int remaining: 5

    function execute(text, cb, timeout) {
        label.text = text
        callback = cb
        remaining = (timeout || 5000) / 1000
        visible = true
        timer.restart()
    }

    visible: false
    z: 200
    width: parent ? parent.width : 0
    height: Theme.itemSizeLarge
    color: "#ee0d2533"

    Label { id: label; anchors.centerIn: parent; color: Theme.highlightColor }
    Label {
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
        text: popup.remaining + "  ✕"
        color: Theme.secondaryColor
    }
    MouseArea { anchors.fill: parent; onClicked: { timer.stop(); popup.visible = false } }
    Timer {
        id: timer
        interval: 1000
        repeat: true
        onTriggered: {
            popup.remaining -= 1
            if (popup.remaining <= 0) { stop(); popup.visible = false; popup.callback() }
        }
    }
}
