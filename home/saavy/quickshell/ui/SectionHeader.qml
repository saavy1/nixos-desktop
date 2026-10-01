import QtQuick
import qs

// Mono uppercase label followed by a hairline, with optional trailing text.
Item {
    id: root

    property string text
    property string trailing
    property string trailingTone: "faint"

    implicitWidth: 240
    implicitHeight: 18

    Label {
        id: title

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        variant: "label"
        tone: "faint"
    }

    Hairline {
        anchors {
            left: title.right
            right: tail.visible ? tail.left : parent.right
            leftMargin: Theme.space.md
            rightMargin: tail.visible ? Theme.space.md : 0
            verticalCenter: parent.verticalCenter
        }
    }

    Label {
        id: tail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.trailing !== ""
        text: root.trailing
        variant: "label"
        tone: root.trailingTone
    }
}
