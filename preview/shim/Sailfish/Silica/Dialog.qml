// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6

Page {
    id: dialog

    property bool canAccept: true

    signal accepted()
    signal rejected()

    function accept() {
        if (!canAccept) return
        accepted()
        pageStack.pop()
    }

    function reject() {
        rejected()
        pageStack.pop()
    }
}
