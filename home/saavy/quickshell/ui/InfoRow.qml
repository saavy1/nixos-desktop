import QtQuick
import qs

// Mono label / value pair on one line, with a hairline below unless `last`.
Item {
    id: root

    property string label
    property string value
    property string valueTone: "base"
    property int labelWidth: 150
    property bool last: false

    width: parent ? parent.width : 0
    height: 34

    Label {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        variant: "label"
        tone: "faint"
    }

    Label {
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: root.labelWidth
            verticalCenter: parent.verticalCenter
        }
        horizontalAlignment: Text.AlignRight
        text: root.value
        variant: "numeric"
        tone: root.valueTone
        elide: Text.ElideMiddle
    }

    Hairline {
        visible: !root.last
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
    }
}
