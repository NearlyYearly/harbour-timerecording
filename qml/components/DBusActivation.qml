// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Nemo.DBus 2.0

// Lets a tapped notification bring the app to the front. When the app is not running,
// D-Bus starts it through /usr/share/dbus-1/services/org.timerecord.harbour-timerecord.service.
// The sandbox allows owning <OrganizationName>.<ApplicationName> from the desktop file.
DBusAdaptor {
    id: adaptor

    readonly property string serviceName: "org.timerecord.harbour-timerecord"
    readonly property string objectPath: "/org/timerecord/TimeRecording"
    readonly property string interfaceName: "org.timerecord.TimeRecording"

    signal activated()

    // Default action for notifications: tap opens the app on today.
    function notificationAction() {
        return {
            "name": "default",
            "displayName": qsTr("Open"),
            "icon": "harbour-timerecord",
            "service": serviceName,
            "path": objectPath,
            "iface": interfaceName,
            "method": "activate",
            "arguments": []
        }
    }

    service: serviceName
    path: objectPath
    iface: interfaceName
    xml: '<interface name="org.timerecord.TimeRecording">\n'
       + '  <method name="activate"/>\n'
       + '</interface>\n'

    function activate() {
        adaptor.activated()
    }
}
