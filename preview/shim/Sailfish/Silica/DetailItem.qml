import QtQuick 2.6

// Preview stand-in for Silica's DetailItem: label in the left half, value in the right, both wrap.
Item {
    id: item
    property alias label: labelText.text
    property alias value: valueText.text
    property real leftMargin: Theme.horizontalPageMargin
    property real rightMargin: Theme.horizontalPageMargin

    width: parent ? parent.width : 0
    height: Math.max(labelText.height, valueText.height) + 2 * Theme.paddingSmall

    Text {
        id: labelText
        x: item.leftMargin
        y: Theme.paddingSmall
        width: item.width / 2 - item.leftMargin - Theme.paddingSmall
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.Wrap
        color: Theme.secondaryHighlightColor
        font.pixelSize: Theme.fontSizeSmall
    }
    Text {
        id: valueText
        x: item.width / 2 + Theme.paddingSmall
        y: Theme.paddingSmall
        width: item.width / 2 - item.rightMargin - Theme.paddingSmall
        wrapMode: Text.Wrap
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeSmall
    }
}
