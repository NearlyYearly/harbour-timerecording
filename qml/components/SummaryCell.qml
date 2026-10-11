import QtQuick 2.6
import Sailfish.Silica 1.0

Column {
    property alias label: caption.text
    property alias value: number.text
    property alias valueColor: number.color

    Label {
        id: number
        anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.highlightColor
    }
    Label {
        id: caption
        anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryColor
    }
}
