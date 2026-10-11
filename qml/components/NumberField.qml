import QtQuick 2.6
import Sailfish.Silica 1.0

// Integer setting field; emits committed(value) when a valid value is left.
TextField {
    id: field

    property int value: 0
    property int minimum: 0
    property int maximum: 9999

    signal committed(int value)

    text: String(value)
    inputMethodHints: Qt.ImhDigitsOnly
    validator: IntValidator { bottom: field.minimum; top: field.maximum }
    EnterKey.iconSource: "image://theme/icon-m-enter-close"
    EnterKey.onClicked: focus = false

    onActiveFocusChanged: {
        if (activeFocus) return
        if (acceptableInput && Number(text) !== value) committed(Number(text))
        else text = String(value)
    }
    onValueChanged: if (!activeFocus) text = String(value)
}
