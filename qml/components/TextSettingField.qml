// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Text setting field; emits committed(entered) when it is left with a changed text.
// A required field left empty goes back to its value.
TextField {
    id: field

    property string value
    property bool required: false

    signal committed(string entered)

    width: parent ? parent.width : 0
    text: value
    EnterKey.iconSource: "image://theme/icon-m-enter-close"
    EnterKey.onClicked: focus = false

    onActiveFocusChanged: {
        if (activeFocus || text === value) return
        if (required && !text.trim()) text = value
        else committed(text)
    }
    onValueChanged: if (!activeFocus) text = value
}
