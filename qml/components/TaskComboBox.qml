// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Task picker. `taskId` is the selection (null = no task); `picked` fires only on user choice.
ComboBox {
    id: combo

    property var tasks: []
    property var taskId: null
    property bool allowNone: false

    signal picked(var value)

    readonly property var entries: allowNone ? [{ id: null, name: qsTr("No task"), color: "" }].concat(tasks || [])
                                             : (tasks || [])

    function sync() {
        if (!entries) return
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].id === taskId) { currentIndex = i; return }
        }
        currentIndex = entries.length > 0 ? 0 : -1
    }

    label: qsTr("Task")
    onEntriesChanged: sync()
    onTaskIdChanged: sync()

    menu: ContextMenu {
        Repeater {
            model: combo.entries
            MenuItem {
                text: modelData.name
                onClicked: {
                    combo.taskId = modelData.id
                    combo.picked(modelData.id)
                }
            }
        }
    }
}
