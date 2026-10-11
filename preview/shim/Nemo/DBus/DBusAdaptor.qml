import QtQuick 2.6

// Preview stand-in: no bus; registers with the preview window so a tapped
// notification toast can call the adaptor's method like D-Bus would.
QtObject {
    property string service
    property string path
    property string iface
    property string xml
    property int bus: 0

    function emitSignal(name, args) { console.log("DBUS signal " + name) }

    Component.onCompleted: if (typeof __previewRegisterAdaptor === "function") __previewRegisterAdaptor(this)
}
