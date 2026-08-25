import QtQuick

Rectangle {
    property bool vertical: true

    width: vertical ? 1 : parent ? parent.width : 0
    height: vertical ? 20 : 1
    color: Theme.border
}
