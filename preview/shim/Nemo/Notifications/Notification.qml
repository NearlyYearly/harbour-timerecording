import QtQuick 2.6

// Preview stand-in: logs the notification and shows it as a toast in the preview window.
QtObject {
    property string appName
    property string appIcon
    property string category
    property string summary
    property string body
    property string previewSummary
    property string previewBody
    property bool isTransient: false
    property int expireTimeout: -1
    property var remoteActions: []

    function publish() {
        console.log("NOTIFICATION " + summary + " | " + body)
        if (typeof __previewNotify === "function") __previewNotify(summary, body, remoteActions)
    }
    function close() { }
}
