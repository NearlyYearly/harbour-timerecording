import QtQuick 2.6

Item {
    property alias title: titleLabel.text
    property alias description: descLabel.text

    width: parent ? parent.width : 0
    height: Theme.itemSizeLarge

    Label {
        id: titleLabel
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; left: parent.left; leftMargin: 80 }
        y: descLabel.text ? 20 : (parent.height - height) / 2
        horizontalAlignment: Text.AlignRight
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeLarge
        truncationMode: TruncationMode.Fade
    }
    Label {
        id: descLabel
        visible: text.length > 0
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; top: titleLabel.bottom }
        color: Theme.secondaryHighlightColor
        font.pixelSize: Theme.fontSizeSmall
    }
}
