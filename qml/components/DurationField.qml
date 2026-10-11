// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "Format.js" as Format

// Text field for durations in "h:mm"; emits committed(minutes) when a valid value is left.
TextField {
    id: field

    property int minutes: 0
    property bool signed: false

    signal committed(int minutes)

    text: Format.duration(minutes)
    inputMethodHints: Qt.ImhPreferNumbers | Qt.ImhNoPredictiveText
    validator: RegExpValidator { regExp: field.signed ? /^-?\d{1,3}(:\d{0,2})?$/ : /^\d{1,2}(:\d{0,2})?$/ }
    description: qsTr("h:mm")
    EnterKey.iconSource: "image://theme/icon-m-enter-close"
    EnterKey.onClicked: focus = false

    function commit() {
        var value = Format.parseDuration(text)
        if (isNaN(value) || (!signed && value < 0)) {
            text = Format.duration(minutes)
            return
        }
        if (value !== minutes) committed(value)
        text = Format.duration(value)
    }

    onActiveFocusChanged: if (!activeFocus) commit()
    onMinutesChanged: if (!activeFocus) text = Format.duration(minutes)
}
