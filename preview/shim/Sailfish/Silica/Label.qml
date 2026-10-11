import QtQuick 2.6

Text {
    property int truncationMode: 0
    color: Theme.primaryColor
    font.pixelSize: Theme.fontSizeMedium
    elide: truncationMode !== 0 && wrapMode === Text.NoWrap ? Text.ElideRight : Text.ElideNone
    textFormat: Text.PlainText
}
