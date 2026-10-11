import QtQuick 2.6

// Preview stand-in for Silica's ColorPickerDialog: a grid of the same default colors.
Dialog {
    id: dialog

    property color color
    property var colors: ["#e60003", "#e6007c", "#e700cc", "#9d00e7", "#7b00e6", "#5d00e5",
                          "#0077e7", "#01a9e7", "#00cce7", "#00e696", "#00e600", "#99e600",
                          "#e3e601", "#e5bc00", "#e78601"]

    Column {
        width: parent.width
        DialogHeader { acceptText: "Choose color" }
        Grid {
            x: Theme.horizontalPageMargin
            columns: 4
            spacing: Theme.paddingLarge
            Repeater {
                model: dialog.colors
                Rectangle {
                    width: Theme.itemSizeMedium
                    height: width
                    color: modelData
                    border.width: Qt.colorEqual(dialog.color, modelData) ? Theme.paddingSmall : 0
                    border.color: Theme.primaryColor
                    MouseArea { anchors.fill: parent; onClicked: { dialog.color = modelData; dialog.accept() } }
                }
            }
        }
    }
}
