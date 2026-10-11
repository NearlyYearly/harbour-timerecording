import QtQuick 2.6
import Sailfish.Silica 1.0

// Text button for the bottom bar, with an optional second line (e.g. what undo will revert).
BackgroundItem {
    id: button

    property alias text: label.text
    property alias hint: hintLabel.text

    height: parent.height
    opacity: enabled ? 1 : Theme.opacityLow

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.paddingSmall
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.highlightBackgroundColor, Theme.opacityFaint)
    }
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingMedium
        Label {
            id: label
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: button.highlighted ? Theme.highlightColor : Theme.primaryColor
        }
        Label {
            id: hintLabel
            width: parent.width
            visible: text.length > 0
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }
    }
}
