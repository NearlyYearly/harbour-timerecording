import QtQuick 2.6

Item {
    id: placeholder

    property alias text: mainLabel.text
    property alias hintText: hintLabel.text

    visible: enabled
    Component.onCompleted: {
        var f = parent
        while (f && f.contentY === undefined) f = f.parent
        if (f) parent = f
    }
    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.horizontalPageMargin
        spacing: Theme.paddingMedium
        Label {
            id: mainLabel
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeExtraLarge
        }
        Label {
            id: hintLabel
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.secondaryHighlightColor
        }
    }
}
