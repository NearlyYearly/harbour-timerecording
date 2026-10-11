import QtQuick 2.6

BackgroundItem {
    id: button

    property string label
    property string value
    property string description

    height: Theme.itemSizeSmall + (description ? Theme.fontSizeExtraSmall + Theme.paddingSmall : 0)

    Row {
        x: Theme.horizontalPageMargin
        y: Theme.paddingLarge
        spacing: Theme.paddingMedium
        Label { text: button.label }
        Label { text: button.value; color: Theme.highlightColor }
    }
    Label {
        visible: button.description.length > 0
        x: Theme.horizontalPageMargin
        y: Theme.itemSizeSmall - Theme.paddingMedium
        width: parent.width - 2 * x
        text: button.description
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryColor
    }
}
