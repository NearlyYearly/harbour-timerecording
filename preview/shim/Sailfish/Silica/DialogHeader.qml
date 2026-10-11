import QtQuick 2.6

Item {
    id: header

    property string title
    property string acceptText: "Accept"
    property string cancelText: "Cancel"

    function _dialog() {
        var p = parent
        while (p && p.canAccept === undefined) p = p.parent
        return p
    }

    width: parent ? parent.width : 0
    height: Theme.itemSizeLarge + (title ? Theme.itemSizeExtraSmall : 0)

    Row {
        width: parent.width
        height: Theme.itemSizeLarge
        Repeater {
            model: [header.cancelText, header.acceptText]
            Rectangle {
                width: header.width / 2
                height: parent.height
                color: mouse.pressed ? "#333a7da6" : "transparent"
                readonly property bool isAccept: index === 1
                Label {
                    anchors.centerIn: parent
                    text: modelData
                    color: parent.isAccept && header._dialog() && !header._dialog().canAccept
                           ? Theme.secondaryColor : Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    onClicked: {
                        var d = header._dialog()
                        if (!d) return
                        if (parent.isAccept) d.accept()
                        else d.reject()
                    }
                }
            }
        }
    }
    Label {
        visible: header.title.length > 0
        y: Theme.itemSizeLarge
        anchors.right: parent.right
        anchors.rightMargin: Theme.horizontalPageMargin
        text: header.title
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeLarge
    }
}
