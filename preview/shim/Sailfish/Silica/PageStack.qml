import QtQuick 2.15

// Page stack with Silica's gestures: swipe right goes back (a dialog is cancelled),
// swipe left on a dialog accepts it. The page follows the finger. On pages that swipe
// horizontally themselves (week/month pagers) the back swipe starts at the left edge only.
Item {
    id: stack

    property var pages: []
    readonly property int depth: pages.length
    readonly property var currentPage: pages.length ? pages[pages.length - 1] : null
    readonly property var previousPage: pages.length > 1 ? pages[pages.length - 2] : null
    readonly property real threshold: width / 4
    property bool currentScrollsSideways: false

    function _component(page) {
        if (typeof page === "string" || page instanceof String) {
            var s = String(page)
            if (s.indexOf("Sailfish.Silica.") === 0)
                s = Qt.resolvedUrl(s.substr("Sailfish.Silica.".length) + ".qml")
            var c = Qt.createComponent(s)
            if (c.status === Component.Error) console.warn(c.errorString())
            return c
        }
        if (page && page.createObject) return page
        if (page && page.toString().indexOf("file:") === 0) return Qt.createComponent(page)
        return null
    }

    function _scrollsSideways(item) {
        if (!item) return false
        if (item.orientation === ListView.Horizontal && item.contentX !== undefined) return true
        for (var i = 0; i < item.children.length; i++)
            if (_scrollsSideways(item.children[i])) return true
        return false
    }

    function push(page, properties) {
        var component = _component(page)
        if (!component) {
            console.warn("pageStack.push: cannot load", page)
            return null
        }
        var obj = component.createObject(stack, properties || {})
        if (!obj) {
            console.warn("pageStack.push failed:", component.errorString())
            return null
        }
        if (currentPage) currentPage.visible = false
        var list = pages.slice()
        list.push(obj)
        pages = list
        currentScrollsSideways = _scrollsSideways(obj)
        return obj
    }

    // pop() removes the top page, pop(page) everything above `page`.
    function pop(page) {
        if (pages.length <= 1) return
        var list = pages.slice()
        var stopAt = page ? list.indexOf(page) : list.length - 2
        if (stopAt < 0) stopAt = list.length - 2
        while (list.length > stopAt + 1) {
            var top = list.pop()
            top.visible = false
            top.destroy(500)
        }
        pages = list
        currentPage.x = 0
        currentPage.visible = true
        currentScrollsSideways = _scrollsSideways(currentPage)
    }

    function _isDialog(page) {
        return page && page.canAccept !== undefined && typeof page.accept === "function"
    }

    function _dragMoved(dx) {
        if (!currentPage) return
        if (dx < 0 && !_isDialog(currentPage)) dx = 0
        currentPage.x = dx
        if (previousPage) previousPage.visible = dx > 0
    }

    function _dragEnded(dx) {
        var page = currentPage
        if (!page) return
        if (dx > threshold) {
            if (_isDialog(page)) page.reject()
            else pop()
        } else if (dx < -threshold && _isDialog(page) && page.canAccept) {
            page.accept()
        } else {
            snapBack.target = page
            snapBack.start()
            if (previousPage) previousPage.visible = false
        }
    }

    // A handler on the stack (the pages' parent) lets taps and vertical scrolling reach the
    // page and only takes over horizontal drags.
    DragHandler {
        enabled: stack.depth > 1 && !stack.currentScrollsSideways
        target: null
        yAxis.enabled: false
        property real lastX: 0
        onTranslationChanged: if (active) { lastX = translation.x; stack._dragMoved(lastX) }
        onActiveChanged: if (!active) { stack._dragEnded(lastX); lastX = 0 }
    }

    // Pages that swipe sideways themselves: back swipe from the left edge only.
    Item {
        z: 100
        visible: stack.depth > 1 && stack.currentScrollsSideways
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: Theme.paddingLarge * 2
        DragHandler {
            target: null
            yAxis.enabled: false
            property real lastX: 0
            onTranslationChanged: if (active) { lastX = translation.x; stack._dragMoved(lastX) }
            onActiveChanged: if (!active) { stack._dragEnded(lastX); lastX = 0 }
        }
    }

    NumberAnimation {
        id: snapBack
        property: "x"
        to: 0
        duration: 150
        easing.type: Easing.OutQuad
    }
}
