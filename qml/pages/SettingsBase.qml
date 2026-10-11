// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Base for settings sub-pages: loads all values and saves single keys.
Page {
    id: base

    property var values: null

    function save(key, value) {
        backend.mutate("set_setting", [key, value], function(v) { if (v) base.values = v })
    }

    Component.onCompleted: backend.run("get_settings", [], function(v) { base.values = v })
}
