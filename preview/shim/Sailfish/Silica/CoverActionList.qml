import QtQuick 2.6

Row {
    default property alias actions: row.data
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    height: 80
    Row { id: row; height: parent.height }
}
