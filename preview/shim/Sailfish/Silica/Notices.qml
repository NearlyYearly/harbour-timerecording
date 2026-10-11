pragma Singleton
import QtQuick 2.6

// Preview stand-in: the preview window shows the text as a toast.
QtObject {
    signal requested(string text, int duration)
    function show(text, duration, anchor) {
        console.log("NOTICE " + text)
        requested(text, duration || 3000)
    }
}
