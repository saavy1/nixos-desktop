import QtQuick
import qs

Rectangle {
    property bool vertical: false
    property bool strong: false

    implicitWidth: vertical ? 1 : 16
    implicitHeight: vertical ? 18 : 1
    color: strong ? Theme.lineStrong : Theme.line
}
