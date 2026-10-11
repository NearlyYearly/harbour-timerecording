// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

Label {
    x: Theme.horizontalPageMargin
    width: parent ? parent.width - 2 * x : 0
    height: Theme.itemSizeExtraSmall
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignRight
    color: Theme.highlightColor
    font.pixelSize: Theme.fontSizeSmall
}
