// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import QtQuick.Window 2.2

// Desktop stand-in: phone-sized page area plus the cover on the right.
Window {
    id: win

    property var initialPage
    property var cover
    property int allowedOrientations: 1
    readonly property int defaultAllowedOrientations: 1
    property alias pageStack: stack
    default property alias content: overlay.data

    width: 540 + 300
    height: 960
    visible: true
    color: "#0b1117"
    title: "harbour-timerecord preview"

    Rectangle {
        id: phone
        width: 540
        height: parent.height
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: "#1d2b38" }
            GradientStop { position: 1; color: "#0a1016" }
        }

        PageStack { id: stack; anchors.fill: parent }

        Item { id: overlay; anchors.fill: parent }

        // Silica goes back with a swipe; here a button and Escape do it.
        Rectangle {
            visible: stack.depth > 1
            x: 8; y: 8; width: 56; height: 56; radius: 28
            color: backMouse.pressed ? "#3a7da6" : "#55000000"
            z: 100
            Text { anchors.centerIn: parent; text: "‹"; color: "white"; font.pixelSize: 40 }
            MouseArea { id: backMouse; anchors.fill: parent; onClicked: stack.pop() }
        }
        Shortcut { sequence: "Escape"; onActivated: if (stack.depth > 1) stack.pop() }
    }

    Item {
        x: 540 + 33
        y: 120
        width: 234
        height: 374
        Text {
            anchors.bottom: parent.top
            anchors.bottomMargin: 12
            text: "Cover"
            color: "#80ffffff"
            font.pixelSize: 22
        }
        Loader {
            anchors.fill: parent
            sourceComponent: win.cover
        }
    }

    // Silica raises the window; nothing to do on the desktop.
    function activate() { win.requestActivate() }

    // Nemo.DBus stand-in adaptors, so a tapped toast can run the notification's action.
    property var __adaptors: []
    property var __toastActions: []
    function __previewRegisterAdaptor(adaptor) {
        var list = __adaptors.slice()
        list.push(adaptor)
        __adaptors = list
    }
    function __runDefaultAction(actions) {
        for (var i = 0; i < actions.length; i++) {
            var a = actions[i]
            if (a.name !== "default") continue
            for (var j = 0; j < __adaptors.length; j++) {
                var target = __adaptors[j]
                if (target.service === a.service && target.path === a.path && typeof target[a.method] === "function") {
                    console.log("DBUS call " + a.service + " " + a.method)
                    target[a.method].apply(target, a.arguments || [])
                    return true
                }
            }
            console.log("DBUS no receiver for " + a.service)
        }
        return false
    }

    // Called by the Nemo.Notifications stand-in.
    function __previewNotify(summary, body, actions) {
        __toastActions = actions || []
        toastSummary.text = summary
        toastBody.text = body
        toast.opacity = 1
        toastTimer.restart()
    }

    Rectangle {
        id: toast
        x: 12
        y: 12
        width: 540 - 24
        height: toastColumn.height + 24
        radius: 12
        z: 1000
        opacity: 0
        visible: opacity > 0
        color: "#ee0d2533"
        border.color: "#72c8f7"
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Column {
            id: toastColumn
            x: 12; y: 12
            width: parent.width - 24
            Text { id: toastSummary; visible: text.length > 0; color: "#72c8f7"; font.pixelSize: 28; width: parent.width; wrapMode: Text.Wrap }
            Text { id: toastBody; color: "white"; font.pixelSize: 24; width: parent.width; wrapMode: Text.Wrap }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: { toast.opacity = 0; win.__runDefaultAction(win.__toastActions) }
        }
        Timer { id: toastTimer; interval: 6000; onTriggered: toast.opacity = 0 }
    }

    Connections {
        target: Notices
        onRequested: win.__previewNotify("", text, [])
    }

    Component.onCompleted: {
        stack.push(initialPage)
        var args = Qt.application.arguments
        var i = args.indexOf("--smoke")
        if (i >= 0) smoke.createObject(win, { outDir: "/shots", target: phone })
    }

    Component {
        id: smoke
        Smoke { }
    }
}
