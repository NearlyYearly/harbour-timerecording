import QtQuick 2.6

// Inline menu; ListItem and ComboBox reparent it under themselves.
Rectangle {
    id: menu

    property var owner: null
    default property alias content: column.data

    function items() {
        var list = []
        for (var i = 0; i < column.children.length; i++)
            if (column.children[i].__isMenuItem) list.push(column.children[i])
        return list
    }

    function _menuItemClicked(item) {
        if (owner && owner._menuClosed) owner._menuClosed(items().indexOf(item))
    }

    width: parent ? parent.width : 0
    height: column.height
    color: "#cc0d2533"

    Column {
        id: column
        width: parent.width
    }
}
